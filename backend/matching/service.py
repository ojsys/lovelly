"""Matching: queue, matcher tick, sessions (FR-6..FR-9, FR-12, SF-1, SF-7).

Short-lived state lives in Redis (PRD: Data model):
  mq:queue:{mode}   ZSET user -> joined_at
  mq:ticket:{user}  JSON ticket (+ "widened" once match.widened was sent)
  mq:recent:{user}  ZSET peer -> matched_at, for the 24 h re-pair rule (FR-7)
  mq:presence       ZSET user -> last seen (online count)
  mq:gone           ZSET user -> disconnected_at (10 s grace before peer_left)
  mq:skips:{user}   consecutive quick skips; mq:cooldown:{user} (SF-7)
"""

import json
import logging
import time
import uuid
from datetime import timedelta

from django.db.models import Q
from django.utils import timezone
from rest_framework import status

from accounts.models import Profile, User, UserInterest
from accounts.services.onboarding import age_on
from core.exceptions import ApiError
from core.realtime import batched, send_to_user
from core.redis import get_redis
from safety.models import Block

from . import calls
from .models import MatchSession
from .pairing import WIDEN_AFTER_SECONDS, Ticket, pick_pairs

logger = logging.getLogger(__name__)

MODES = [m.value for m in MatchSession.Mode]
RECENT_SECONDS = 24 * 3600
DISCONNECT_GRACE_SECONDS = 10
PRESENCE_WINDOW_SECONDS = 60
QUICK_SKIP_SECONDS = 5
QUICK_SKIPS_FOR_COOLDOWN = 3
COOLDOWN_SECONDS = 120
NEW_ACCOUNT_MATCH_LIMIT = 30

_CLAIM = """
if redis.call('ZSCORE', KEYS[1], ARGV[1]) and redis.call('ZSCORE', KEYS[1], ARGV[2]) then
  redis.call('ZREM', KEYS[1], ARGV[1], ARGV[2])
  redis.call('DEL', KEYS[2], KEYS[3])
  return 1
end
return 0
"""


def _queue(mode):
    return f"mq:queue:{mode}"


def _ticket(user_id):
    return f"mq:ticket:{user_id}"


def _r():
    return get_redis()


# --- Presence --------------------------------------------------------------------------


def touch_presence(user_id, now=None) -> None:
    _r().zadd("mq:presence", {str(user_id): now or time.time()})


def online_count(now=None) -> int:
    now = now or time.time()
    r = _r()
    r.zremrangebyscore("mq:presence", 0, now - PRESENCE_WINDOW_SECONDS)
    return r.zcard("mq:presence")


# --- Queue -----------------------------------------------------------------------------


def active_session(user_id) -> MatchSession | None:
    return (
        MatchSession.objects.filter(Q(user_a_id=user_id) | Q(user_b_id=user_id), ended_at=None)
        .order_by("-started_at")
        .first()
    )


def _check_can_match(user: User) -> None:
    """SF-1 (verified only) and SF-7 (new-account cap, quick-skip cooldown)."""
    profile = Profile.objects.filter(user=user).first()
    if user.status != User.Status.ACTIVE or not (profile and profile.is_verified):
        raise ApiError("not_verified", "Finish verification first.", status.HTTP_403_FORBIDDEN)
    wait = _r().ttl(f"mq:cooldown:{user.id}")
    if wait and wait > 0:
        raise ApiError("cooldown", "Take a short break, then try again.", 429, retry_after=wait)
    first_day_ends = user.created_at + timedelta(hours=24)
    if timezone.now() < first_day_ends:
        count = MatchSession.objects.filter(
            Q(user_a=user) | Q(user_b=user), started_at__lt=first_day_ends
        ).count()
        if count >= NEW_ACCOUNT_MATCH_LIMIT:
            wait = int((first_day_ends - timezone.now()).total_seconds())
            raise ApiError(
                "match_limit", "You've hit today's limit for new accounts.", 429, retry_after=wait
            )


def join(user: User, mode: str, filters: dict | None = None, now=None) -> None:
    if mode not in MODES:
        raise ApiError("invalid_mode", "Pick video, voice or text.")
    if filters:
        # FR-8: filters are Plus / pay-as-you-go features (M7).
        raise ApiError("filters_unavailable", "Filters aren't available yet.")
    if active_session(user.id):
        raise ApiError("in_session", "Finish your current chat first.", status.HTTP_409_CONFLICT)
    _check_can_match(user)

    profile = Profile.objects.get(user=user)
    ticket = {
        "user_id": str(user.id),
        "mode": mode,
        "joined_at": now or time.time(),
        "interests": list(user.interests.values_list("interest_id", flat=True)),
        "languages": [lang.lower() for lang in profile.languages],
        "city": profile.city,
        "widened": False,
    }
    r = _r()
    pipe = r.pipeline()
    for m in MODES:
        pipe.zrem(_queue(m), str(user.id))
    pipe.set(_ticket(user.id), json.dumps(ticket))
    pipe.zadd(_queue(mode), {str(user.id): ticket["joined_at"]})
    pipe.execute()


def leave(user_id) -> None:
    r = _r()
    pipe = r.pipeline()
    for m in MODES:
        pipe.zrem(_queue(m), str(user_id))
    pipe.delete(_ticket(user_id))
    pipe.execute()


def is_queued(user_id) -> bool:
    return any(_r().zscore(_queue(m), str(user_id)) is not None for m in MODES)


# --- Matcher tick ----------------------------------------------------------------------


def _load_tickets(mode) -> list[dict]:
    r = _r()
    ids = r.zrange(_queue(mode), 0, -1)
    if not ids:
        return []
    raws = r.mget([_ticket(i) for i in ids])
    tickets = []
    for user_id, raw in zip(ids, raws, strict=True):
        if raw is None:  # stale queue entry
            r.zrem(_queue(mode), user_id)
            continue
        tickets.append(json.loads(raw))
    return tickets


def _exclusions(user_ids: list[str], now: float):
    """Blocked pairs (either direction, SF-5) and pairs matched in the last 24 h (FR-7)."""
    blocked = set()
    # Only blocks where both people are queued can affect this tick.
    for a, b in Block.objects.filter(blocker_id__in=user_ids, blocked_id__in=user_ids).values_list(
        "blocker_id", "blocked_id"
    ):
        blocked |= {(str(a), str(b)), (str(b), str(a))}
    r = _r()
    pipe = r.pipeline()
    for uid in user_ids:
        pipe.zrangebyscore(f"mq:recent:{uid}", now - RECENT_SECONDS, "+inf")
    recent = {
        (uid, peer) for uid, peers in zip(user_ids, pipe.execute(), strict=True) for peer in peers
    }
    return lambda a, b: (a, b) in blocked or (a, b) in recent or (b, a) in recent


def _summaries(pairs: list[tuple[str, str]]) -> dict[tuple[str, str], dict]:
    """Peer summaries for (viewer, peer) pairs, in a constant number of queries."""
    ids = {uid for pair in pairs for uid in pair}
    users = {str(u.id): u for u in User.objects.filter(id__in=ids).select_related("profile")}
    interests: dict[str, dict[str, str]] = {uid: {} for uid in ids}
    languages = {uid: {lang.lower() for lang in users[uid].profile.languages} for uid in users}
    for ui in UserInterest.objects.filter(user_id__in=ids).select_related("interest"):
        interests[str(ui.user_id)][ui.interest_id] = ui.interest.label
    today = timezone.now().date()
    out = {}
    for viewer, peer_id in pairs:
        peer = users[peer_id]
        shared = sorted(
            label for slug, label in interests[peer_id].items() if slug in interests[viewer]
        )
        out[(viewer, peer_id)] = {
            "first_name": peer.profile.first_name,
            "age": age_on(peer.dob, today) if peer.dob else None,
            "city": peer.profile.city,
            "shared_interests": shared,
            "shared_languages": sorted(languages[peer_id] & languages[viewer]),
            "verified": peer.profile.is_verified,
        }
    return out


def peer_summary(user_id, peer_id) -> dict:
    return _summaries([(str(user_id), str(peer_id))])[(str(user_id), str(peer_id))]


def _start_sessions(pairs: list[tuple[Ticket, Ticket]], now: float) -> list[MatchSession]:
    """Creates the tick's sessions in bulk and sends match.found to both sides."""
    if not pairs:
        return []
    sessions = MatchSession.objects.bulk_create(
        [
            MatchSession(
                mode=a.mode,
                user_a_id=a.user_id,
                user_b_id=b.user_id,
                room_name=f"s_{uuid.uuid4().hex}",
            )
            for a, b in pairs
        ]
    )
    pipe = _r().pipeline()
    for a, b in pairs:
        for me, peer in ((a, b), (b, a)):
            pipe.zadd(f"mq:recent:{me.user_id}", {peer.user_id: now})
            pipe.expire(f"mq:recent:{me.user_id}", RECENT_SECONDS)
    pipe.execute()
    summaries = _summaries(
        [(me.user_id, peer.user_id) for a, b in pairs for me, peer in ((a, b), (b, a))]
    )
    for session in sessions:
        if session.mode == MatchSession.Mode.VIDEO:
            calls.watch(session)
    for session, (a, b) in zip(sessions, pairs, strict=True):
        for me, peer in ((a, b), (b, a)):
            send_to_user(
                me.user_id,
                "match.found",
                {
                    "session_id": str(session.id),
                    "mode": session.mode,
                    "peer": summaries[(me.user_id, peer.user_id)],
                    "room_name": session.room_name,
                    "media_token": calls.media_token(session, me.user_id),
                    "media_url": calls.media_url() if session.mode != "text" else None,
                },
            )
    return sessions


def run_tick(now=None) -> list[MatchSession]:
    """One matcher pass over every mode queue. Safe to run in several workers at once."""
    with batched():
        return _run_tick(now or time.time())


def _run_tick(now: float) -> list[MatchSession]:
    r = _r()
    claim = r.register_script(_CLAIM)
    started = []
    for mode in MODES:
        raw = _load_tickets(mode)
        for t in raw:
            if not t["widened"] and now - t["joined_at"] >= WIDEN_AFTER_SECONDS:
                t["widened"] = True
                r.set(_ticket(t["user_id"]), json.dumps(t), xx=True)
                send_to_user(t["user_id"], "match.widened", {"mode": mode, "criteria": "anyone"})
        tickets = [
            Ticket(
                user_id=t["user_id"],
                mode=t["mode"],
                joined_at=t["joined_at"],
                interests=frozenset(t["interests"]),
                languages=frozenset(t["languages"]),
                city=t["city"],
            )
            for t in raw
        ]
        tickets = _drop_ineligible(tickets)
        if len(tickets) < 2:
            continue
        excluded = _exclusions([t.user_id for t in tickets], now)
        claimed = [
            (a, b)
            for a, b in pick_pairs(tickets, now, excluded)
            if claim(
                keys=[_queue(mode), _ticket(a.user_id), _ticket(b.user_id)],
                args=[a.user_id, b.user_id],
            )
        ]
        try:
            started += _start_sessions(claimed, now)
        except Exception:
            # Don't strand claimed users: put them back in the queue for the next tick.
            logger.exception("could not start %d sessions in %s", len(claimed), mode)
            for a, b in claimed:
                for t in (a, b):
                    _requeue_ticket(t)
    return started


def _requeue_ticket(t: Ticket) -> None:
    ticket = {
        "user_id": t.user_id,
        "mode": t.mode,
        "joined_at": t.joined_at,
        "interests": sorted(t.interests),
        "languages": sorted(t.languages),
        "city": t.city,
        "widened": True,
    }
    pipe = _r().pipeline()
    pipe.set(_ticket(t.user_id), json.dumps(ticket))
    pipe.zadd(_queue(t.mode), {t.user_id: t.joined_at})
    pipe.execute()


def _drop_ineligible(tickets: list[Ticket]) -> list[Ticket]:
    """Removes tickets of users who were deleted, banned or suspended while queued."""
    ids = [t.user_id for t in tickets]
    eligible = {
        str(uid)
        for uid in User.objects.filter(
            id__in=ids, is_active=True, status=User.Status.ACTIVE
        ).values_list("id", flat=True)
    }
    for t in tickets:
        if t.user_id not in eligible:
            leave(t.user_id)
    return [t for t in tickets if t.user_id in eligible]


# --- Ending sessions (FR-12, SF-7) -----------------------------------------------------


def _record_skip(session: MatchSession, skipped_id, now: float) -> None:
    """SF-7: three skips within 5 s in a row -> 2 minute cooldown."""
    r = _r()
    key = f"mq:skips:{skipped_id}"
    quick = (now - session.started_at.timestamp()) < QUICK_SKIP_SECONDS
    if not quick:
        r.delete(key)
        return
    if r.incr(key) >= QUICK_SKIPS_FOR_COOLDOWN:
        r.delete(key)
        r.set(f"mq:cooldown:{skipped_id}", 1, ex=COOLDOWN_SECONDS)


def end_session(session_id, user, reason: str, now=None) -> MatchSession | None:
    """`reason` is next | end (by `user`), peer_left (disconnect) or blocked.

    The other person gets `session.ended`. On Next, `user` goes straight back into the
    queue in the same mode.
    """
    now = now or time.time()
    calls.stop_watching(session_id)
    updated = MatchSession.objects.filter(id=session_id, ended_at=None).update(
        ended_at=timezone.now(),
        end_reason=reason,
        ended_by=user if reason in ("next", "end") else None,
    )
    session = MatchSession.objects.filter(id=session_id).first()
    if not updated or session is None:
        return None  # already ended
    try:
        calls.close_room(session)
    except Exception:
        logger.exception("could not close room for session %s", session.id)
    peer_id = session.peer_of(user.id)
    peer_reason = {
        "next": "peer_next",
        "peer_left": "peer_left",
        "blocked": "peer_left",
        "moderation": "moderation",
    }.get(reason, "peer_left")
    send_to_user(peer_id, "session.ended", {"session_id": str(session.id), "reason": peer_reason})
    send_to_user(user.id, "session.ended", {"session_id": str(session.id), "reason": reason})
    if reason == "next":
        _record_skip(session, peer_id, now)
        _r().delete(f"mq:skips:{user.id}")
        try:
            join(user, session.mode, now=now)
        except ApiError as e:
            send_to_user(user.id, "error", {"code": e.error_code, "detail": str(e.detail)})
    return session


# --- Disconnects (NFR: reconnect within 10 s keeps the session) --------------------------


def on_connect(user_id) -> None:
    _r().zrem("mq:gone", str(user_id))
    touch_presence(user_id)


def on_disconnect(user_id, now=None) -> None:
    leave(user_id)
    r = _r()
    r.zrem("mq:presence", str(user_id))
    if active_session(user_id):
        r.zadd("mq:gone", {str(user_id): now or time.time()})


def sweep_disconnects(now=None) -> int:
    """End sessions whose user hasn't come back within the grace period."""
    with batched():
        return _sweep_disconnects(now or time.time())


def _sweep_disconnects(now: float) -> int:
    r = _r()
    gone = r.zrangebyscore("mq:gone", 0, now - DISCONNECT_GRACE_SECONDS)
    ended = 0
    for user_id in gone:
        r.zrem("mq:gone", user_id)
        session = active_session(user_id)
        user = User.objects.filter(id=user_id).first()
        if session and user and end_session(session.id, user, "peer_left", now=now):
            ended += 1
    return ended


def purge_stranger_messages(now=None) -> int:
    """PRD data model: stranger messages are deleted after 7 days unless a report holds them."""
    from chat.models import Message
    from safety.models import Report

    cutoff = (now or timezone.now()) - timedelta(days=7)
    held = Report.objects.filter(
        Q(status__in=[Report.Status.OPEN, Report.Status.ESCALATED]) | Q(legal_hold=True)
    ).values("session_id")
    deleted, _ = (
        Message.objects.filter(session__ended_at__lt=cutoff).exclude(session_id__in=held).delete()
    )
    return deleted
