"""Chat (FR-15..FR-18, SF-8): stranger sessions and friend chats share these rules."""

import time
from dataclasses import dataclass

from django.db.models import F
from django.utils import timezone

from accounts.models import User
from accounts.services.push import notify
from core.exceptions import ApiError
from core.providers.push import Push
from core.realtime import send_to_user
from core.redis import get_redis
from matching.models import MatchSession

from . import filters
from .models import Friendship, Message

MAX_BODY = 1000
RATE_LIMIT = 20  # messages per window
RATE_WINDOW_SECONDS = 10


@dataclass(frozen=True)
class Conversation:
    """A live stranger session or an accepted friendship."""

    session: MatchSession | None = None
    friendship: Friendship | None = None

    @property
    def members(self) -> tuple:
        if self.session:
            return (self.session.user_a_id, self.session.user_b_id)
        return (self.friendship.requester_id, self.friendship.addressee_id)

    def peer_of(self, user_id):
        a, b = self.members
        return b if str(a) == str(user_id) else a

    @property
    def ref(self) -> dict:
        """How events name this conversation: session_id (strangers) or chat_id (friends)."""
        if self.session:
            return {"session_id": str(self.session.id)}
        return {"chat_id": str(self.friendship.id)}


def conversation(user, session_id=None, chat_id=None) -> Conversation:
    if chat_id:
        from .friends import accepted_friendship

        return Conversation(friendship=accepted_friendship(user, chat_id))
    session = MatchSession.objects.filter(id=session_id).first() if session_id else None
    if session is None or not session.has(user.id):
        raise ApiError("not_found", "Chat not found.", 404)
    if session.ended_at:
        raise ApiError("session_ended", "This chat has ended.", 409)
    return Conversation(session=session)


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


def send_message(session_id, user: User, body: str, chat_id=None) -> Message:
    body = (body or "").strip()
    if not body:
        raise ApiError("empty", "Type a message first.")
    if len(body) > MAX_BODY:
        raise ApiError("too_long", f"Keep it under {MAX_BODY} characters.")
    conv = conversation(user, session_id, chat_id)
    _rate_limit(user.id)
    reason = filters.check(body)
    message = Message.objects.create(
        session=conv.session,
        friendship=conv.friendship,
        sender=user,
        body=body,
        flagged=bool(reason),
        flag_reason=reason,
    )
    if reason:
        # SF-8: raise the sender's risk score.
        User.objects.filter(id=user.id).update(risk_score=F("risk_score") + 1)
    payload = {**conv.ref, "message": serialize(message)}
    for uid in conv.members:
        send_to_user(uid, "chat.message", payload)
    if conv.friendship:
        # FR-17: friends whose app is closed get a push. No message text on the lock
        # screen (M5 decision 3).
        notify(
            conv.peer_of(user.id),
            Push(
                "Lovelly",
                f"{user.profile.first_name} sent you a message",
                {"type": "chat", "chat_id": str(conv.friendship.id)},
            ),
        )
    return message


def system_message(friendship: Friendship, sender_id, body: str) -> Message:
    """A line in a friend chat that isn't typed (e.g. "Missed video call")."""
    message = Message.objects.create(
        friendship=friendship, sender_id=sender_id, body=body, kind=Message.Kind.SYSTEM
    )
    for uid in (friendship.requester_id, friendship.addressee_id):
        send_to_user(
            uid, "chat.message", {"chat_id": str(friendship.id), "message": serialize(message)}
        )
    return message


def mark_seen(session_id, user: User, message_id, chat_id=None) -> None:
    """Marks the peer's messages up to `message_id` as seen and tells the peer (FR-17)."""
    conv = conversation(user, session_id, chat_id)
    scope = {"session": conv.session} if conv.session else {"friendship": conv.friendship}
    upto = Message.objects.filter(id=message_id, **scope).first()
    if upto is None:
        return
    updated = (
        Message.objects.filter(seen_at=None, sent_at__lte=upto.sent_at, **scope)
        .exclude(sender=user)
        .update(seen_at=timezone.now())
    )
    if updated:
        send_to_user(conv.peer_of(user.id), "chat.seen", {**conv.ref, "message_id": str(upto.id)})


def typing(session_id, user: User, chat_id=None) -> None:
    conv = conversation(user, session_id, chat_id)
    send_to_user(conv.peer_of(user.id), "chat.typing", conv.ref)
