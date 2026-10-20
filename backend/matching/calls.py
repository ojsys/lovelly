"""Voice and video calls: media tokens, photo reveal, voice → video (FR-10, FR-13, FR-14)."""

import json

from django.conf import settings
from django.utils import timezone

from accounts.models import User
from core.exceptions import ApiError
from core.providers import get_provider
from core.providers.media import CAMERA, MICROPHONE
from core.realtime import send_to_user
from core.redis import get_redis

from .models import MatchSession

PENDING_UPGRADE_SECONDS = 60
MODERATION_CHANNEL = "moderation:rooms"


def sources_for(session: MatchSession) -> list[str]:
    """What each participant may publish: voice is microphone-only until upgraded."""
    if session.mode == MatchSession.Mode.VIDEO or session.upgraded_at:
        return [CAMERA, MICROPHONE]
    return [MICROPHONE]


def media_token(session: MatchSession, user_id) -> str | None:
    if session.mode == MatchSession.Mode.TEXT:
        return None
    return get_provider("media").join_token(
        session.room_name, str(user_id), sources_for(session), settings.MEDIA_TOKEN_TTL_SECONDS
    )


def media_url() -> str:
    return get_provider("media").client_url


def watch(session: MatchSession) -> None:
    """Asks the moderation agent to sample this call's video (SF-2)."""
    get_redis().publish(
        MODERATION_CHANNEL,
        json.dumps({"op": "start", "session_id": str(session.id), "room": session.room_name}),
    )


def stop_watching(session_id) -> None:
    get_redis().publish(
        MODERATION_CHANNEL, json.dumps({"op": "stop", "session_id": str(session_id)})
    )


def close_room(session: MatchSession) -> None:
    if session.mode != MatchSession.Mode.TEXT:
        get_provider("media").close_room(session.room_name)


def _open_call(session_id, user: User, voice_only=False) -> MatchSession:
    session = MatchSession.objects.filter(id=session_id).first()
    if session is None or not session.has(user.id):
        raise ApiError("not_found", "Session not found.", 404)
    if session.ended_at:
        raise ApiError("session_ended", "This call has ended.", 409)
    if session.mode == MatchSession.Mode.TEXT:
        raise ApiError("not_a_call", "This chat isn't a call.", 409)
    if voice_only and session.mode != MatchSession.Mode.VOICE:
        raise ApiError("not_voice", "Only voice calls can do this.", 409)
    return session


def fresh_token(session_id, user: User) -> dict:
    """A new join token for rejoining after a drop (NFR: back within 10 s)."""
    session = _open_call(session_id, user)
    return {"media_token": media_token(session, user.id), "media_url": media_url()}


# --- Photo reveal (FR-13) ----------------------------------------------------------------


def request_reveal(session_id, user: User) -> bool:
    """Records `user` agreeing to reveal. Returns True once both have agreed."""
    session = _open_call(session_id, user, voice_only=True)
    r = get_redis()
    key = f"call:reveal:{session.id}"
    r.sadd(key, str(user.id))
    r.expire(key, 24 * 3600)
    agreed = r.smembers(key)
    peer_id = session.peer_of(user.id)
    if str(peer_id) in agreed:
        for uid in (session.user_a_id, session.user_b_id):
            # Main photos (signed URLs) are added when profile photos exist (M5).
            send_to_user(uid, "reveal.accept", {"session_id": str(session.id), "photo_url": None})
        return True
    send_to_user(peer_id, "reveal.request", {"session_id": str(session.id)})
    return False


# --- Voice → video (FR-14) ---------------------------------------------------------------


def request_upgrade(session_id, user: User) -> None:
    session = _open_call(session_id, user, voice_only=True)
    if session.upgraded_at:
        raise ApiError("already_video", "This call is already on video.", 409)
    get_redis().set(f"call:upgrade:{session.id}", str(user.id), ex=PENDING_UPGRADE_SECONDS)
    send_to_user(session.peer_of(user.id), "upgrade.request", {"session_id": str(session.id)})


def _pending_requester(session: MatchSession, user: User) -> str:
    requester = get_redis().get(f"call:upgrade:{session.id}")
    if requester is None or requester == str(user.id):
        raise ApiError("no_request", "There's no video request to answer.", 409)
    return requester


def accept_upgrade(session_id, user: User) -> None:
    """The other person must accept (FR-14). Both may then publish camera."""
    session = _open_call(session_id, user, voice_only=True)
    _pending_requester(session, user)
    get_redis().delete(f"call:upgrade:{session.id}")
    MatchSession.objects.filter(id=session.id).update(upgraded_at=timezone.now())
    get_provider("media").grant_sources(
        session.room_name, [str(session.user_a_id), str(session.user_b_id)], [CAMERA, MICROPHONE]
    )
    for uid in (session.user_a_id, session.user_b_id):
        send_to_user(uid, "upgrade.accept", {"session_id": str(session.id)})
    watch(session)  # video now flows: start sampling it


def decline_upgrade(session_id, user: User) -> None:
    session = _open_call(session_id, user, voice_only=True)
    requester = _pending_requester(session, user)
    get_redis().delete(f"call:upgrade:{session.id}")
    send_to_user(requester, "upgrade.decline", {"session_id": str(session.id)})
