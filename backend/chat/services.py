"""Stranger text chat (FR-15, FR-17, FR-18, SF-8)."""

import time

from django.db.models import F
from django.utils import timezone

from accounts.models import User
from core.exceptions import ApiError
from core.realtime import send_to_user
from core.redis import get_redis
from matching.models import MatchSession

from . import filters
from .models import Message

MAX_BODY = 1000
RATE_LIMIT = 20  # messages per window
RATE_WINDOW_SECONDS = 10


def _open_session(session_id, user) -> MatchSession:
    session = MatchSession.objects.filter(id=session_id).first()
    if session is None or not session.has(user.id):
        raise ApiError("not_found", "Chat not found.", 404)
    if session.ended_at:
        raise ApiError("session_ended", "This chat has ended.", 409)
    return session


def _rate_limit(user_id) -> None:
    r = get_redis()
    key = f"chat:rate:{user_id}:{int(time.time() // RATE_WINDOW_SECONDS)}"
    if r.incr(key) > RATE_LIMIT:
        raise ApiError("throttled", "Slow down a little.", 429, retry_after=RATE_WINDOW_SECONDS)
    r.expire(key, RATE_WINDOW_SECONDS * 2)


def serialize(message: Message) -> dict:
    return {
        "id": str(message.id),
        "sender_id": str(message.sender_id),
        "body": message.body,
        "kind": message.kind,
        "sent_at": message.sent_at.isoformat(),
        "seen_at": message.seen_at.isoformat() if message.seen_at else None,
        "flagged": message.flagged,
        "flag_reason": message.flag_reason,
    }


def send_message(session_id, user: User, body: str) -> Message:
    body = (body or "").strip()
    if not body:
        raise ApiError("empty", "Type a message first.")
    if len(body) > MAX_BODY:
        raise ApiError("too_long", f"Keep it under {MAX_BODY} characters.")
    session = _open_session(session_id, user)
    _rate_limit(user.id)
    reason = filters.check(body)
    message = Message.objects.create(
        session=session, sender=user, body=body, flagged=bool(reason), flag_reason=reason
    )
    if reason:
        # SF-8: raise the sender's risk score.
        User.objects.filter(id=user.id).update(risk_score=F("risk_score") + 1)
    payload = {"session_id": str(session.id), "message": serialize(message)}
    for uid in (session.user_a_id, session.user_b_id):
        send_to_user(uid, "chat.message", payload)
    return message


def mark_seen(session_id, user: User, message_id) -> None:
    """Marks the peer's messages up to `message_id` as seen and tells the peer (FR-17)."""
    session = _open_session(session_id, user)
    upto = Message.objects.filter(id=message_id, session=session).first()
    if upto is None:
        return
    updated = (
        Message.objects.filter(session=session, seen_at=None, sent_at__lte=upto.sent_at)
        .exclude(sender=user)
        .update(seen_at=timezone.now())
    )
    if updated:
        send_to_user(
            session.peer_of(user.id),
            "chat.seen",
            {"session_id": str(session.id), "message_id": str(upto.id)},
        )


def typing(session_id, user: User) -> None:
    session = _open_session(session_id, user)
    send_to_user(session.peer_of(user.id), "chat.typing", {"session_id": str(session.id)})
