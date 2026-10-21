"""Direct calls between friends (FR-16) and paid rematches (FR-7): ring, accept, decline,
missed.

An accepted call becomes an ordinary MatchSession (with `friendship` or `rematch_of` set),
so rooms, tokens, the moderation agent, reports and blocks all apply unchanged.
"""

import json
import time
import uuid

from accounts.models import Profile, User
from accounts.services.push import notify
from core.exceptions import ApiError
from core.providers.push import Push
from core.realtime import batched, send_to_user
from core.redis import get_redis

from . import pricing, service
from .pairing import Ticket

RING_SECONDS = 30
RINGING = "fc:ringing"


def _key(invite_id):
    return f"fc:invite:{invite_id}"


def _can_call(user: User) -> None:
    from safety.services import effective_status

    profile = Profile.objects.filter(user=user).first()
    if effective_status(user) != User.Status.ACTIVE or not (profile and profile.is_verified):
        raise ApiError("not_verified", "Finish verification first.", 403)


def invite(user: User, chat_id, mode: str, now=None) -> str:
    from chat.friends import accepted_friendship, summary

    if mode not in ("voice", "video"):
        raise ApiError("invalid_mode", "Pick voice or video.")
    f = accepted_friendship(user, chat_id)
    callee_id = f.other(user.id)
    _can_call(user)
    if service.active_session(user.id):
        raise ApiError("in_session", "Finish your current chat first.", 409)
    if service.active_session(callee_id):
        raise ApiError("busy", "They’re in another chat right now.", 409)

    now = now or time.time()
    invite_id = uuid.uuid4().hex
    data = {
        "kind": "friend",
        "caller": str(user.id),
        "callee": str(callee_id),
        "chat": str(f.id),
        "mode": mode,
        "at": now,
    }
    r = get_redis()
    r.set(_key(invite_id), json.dumps(data), ex=RING_SECONDS * 4)
    r.zadd(RINGING, {invite_id: now})
    caller = summary(user)
    send_to_user(
        callee_id,
        "call.incoming",
        {"invite_id": invite_id, "chat_id": str(f.id), "mode": mode, "from": caller},
    )
    send_to_user(
        user.id, "call.ringing", {"invite_id": invite_id, "chat_id": str(f.id), "mode": mode}
    )
    notify(
        callee_id,
        Push(
            "Lovelly",
            f"{caller['first_name']} is calling you ({mode})",
            {"type": "call", "invite_id": invite_id, "chat_id": str(f.id), "mode": mode},
        ),
    )
    return invite_id


def _take(invite_id) -> dict | None:
    """Removes the invite atomically; whoever gets it decides its fate."""
    r = get_redis()
    pipe = r.pipeline()
    pipe.get(_key(invite_id))
    pipe.delete(_key(invite_id))
    pipe.zrem(RINGING, invite_id)
    raw, _, _ = pipe.execute()
    return json.loads(raw) if raw else None


def accept(user: User, invite_id, now=None):
    from chat.models import Friendship

    from .models import MatchSession

    raw = get_redis().get(_key(invite_id))
    data = json.loads(raw) if raw else None
    if data is None or data["callee"] != str(user.id):
        raise ApiError("call_ended", "This call has ended.", 409)
    _can_call(user)
    if _take(invite_id) is None:
        raise ApiError("call_ended", "This call has ended.", 409)
    now = now or time.time()
    caller = Ticket(user_id=data["caller"], mode=data["mode"], joined_at=now)
    callee = Ticket(user_id=data["callee"], mode=data["mode"], joined_at=now)
    if data.get("kind") == "rematch":
        # Both may be waiting in the queue: they leave it (and its holds) for this call.
        service.leave(data["caller"])
        service.leave(data["callee"])
        earlier = MatchSession.objects.get(id=data["rematch_of"])
        with batched():
            (session,) = service._start_sessions([(caller, callee)], now, rematch_of=earlier)
        pricing.bind(session, [data["caller"]], old_ref=f"rematch:{invite_id}", started=now)
        return session
    f = Friendship.objects.get(id=data["chat"])
    with batched():
        (session,) = service._start_sessions([(caller, callee)], now, friendship=f)
    return session


def decline(user: User, invite_id, cancel: bool = False) -> None:
    """Callee declines, or caller hangs up before an answer (a missed call for the callee)."""
    raw = get_redis().get(_key(invite_id))
    data = json.loads(raw) if raw else None
    me = "caller" if cancel else "callee"
    if data is None or data[me] != str(user.id):
        return
    if _take(invite_id) is None:
        return
    other = data["callee"] if cancel else data["caller"]
    send_to_user(other, "call.cancelled" if cancel else "call.declined", {"invite_id": invite_id})
    _release(invite_id, data)
    if cancel:
        _record_missed(data)


def _release(invite_id, data: dict) -> None:
    """An unanswered rematch costs nothing (MN-8)."""
    if data.get("kind") == "rematch":
        from wallet import holds

        holds.release(data["caller"], f"rematch:{invite_id}")


def _record_missed(data: dict) -> None:
    from chat.models import Friendship
    from chat.services import system_message

    if data.get("kind") == "rematch":
        return  # no chat to note it in
    f = Friendship.objects.filter(id=data["chat"]).first()
    if f:
        system_message(f, data["caller"], f"Missed {data['mode']} call")


def sweep_missed(now=None) -> int:
    """Invites nobody answered within 30 s become missed calls."""
    now = now or time.time()
    missed = 0
    for invite_id in get_redis().zrangebyscore(RINGING, 0, now - RING_SECONDS):
        data = _take(invite_id)
        if data is None:
            continue
        for uid in (data["caller"], data["callee"]):
            send_to_user(uid, "call.missed", {"invite_id": invite_id, "chat_id": data.get("chat")})
        _release(invite_id, data)
        _record_missed(data)
        missed += 1
    return missed


# --- Rematch (FR-7, MN-6) ------------------------------------------------------------------

REMATCH_WINDOW_SECONDS = 24 * 3600


def rematch(user: User, session_id, now=None) -> str:
    """Rings someone `user` skipped in the last 24 h. 20 coins (free with Plus), held now and
    taken once the rematch has run 5 s."""
    from chat.friends import blocked
    from safety.models import Report

    from .models import MatchSession

    now = now or time.time()
    earlier = MatchSession.objects.filter(id=session_id).first()
    if earlier is None or not earlier.has(user.id) or earlier.friendship_id:
        raise ApiError("not_found", "Session not found.", 404)
    peer_id = earlier.peer_of(user.id)
    if (
        earlier.end_reason != "next"
        or str(earlier.ended_by_id) != str(user.id)  # you skipped them, not the other way
        or now - earlier.ended_at.timestamp() > REMATCH_WINDOW_SECONDS
    ):
        raise ApiError("cant_rematch", "You can only rematch someone you skipped today.", 409)
    reported = Report.objects.filter(session=earlier, reporter_id__in=[user.id, peer_id]).exists()
    if blocked(user.id, peer_id) or reported:
        raise ApiError("not_found", "Session not found.", 404)
    _can_call(user)
    peer = User.objects.filter(id=peer_id).first()
    if service.active_session(user.id):
        raise ApiError("in_session", "Finish your current chat first.", 409)
    if peer is None or not service.is_online(peer_id) or service.active_session(peer_id):
        raise ApiError("busy", "They’re not available right now.", 409)

    invite_id = uuid.uuid4().hex
    service.leave(user.id)  # no random match while this rings (and no double hold)
    pricing.hold_for_rematch(user, invite_id)
    data = {
        "kind": "rematch",
        "caller": str(user.id),
        "callee": str(peer_id),
        "rematch_of": str(earlier.id),
        "mode": earlier.mode,
        "at": now,
    }
    r = get_redis()
    r.set(_key(invite_id), json.dumps(data), ex=RING_SECONDS * 4)
    r.zadd(RINGING, {invite_id: now})
    caller = service.peer_summary(peer_id, user.id)
    send_to_user(
        peer_id,
        "call.incoming",
        {
            "invite_id": invite_id,
            "chat_id": None,
            "rematch": True,
            "mode": earlier.mode,
            "from": caller,
        },
    )
    send_to_user(
        user.id,
        "call.ringing",
        {"invite_id": invite_id, "chat_id": None, "rematch": True, "mode": earlier.mode},
    )
    return invite_id
