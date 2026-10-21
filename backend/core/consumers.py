import logging

from asgiref.sync import sync_to_async
from channels.db import database_sync_to_async
from channels.generic.websocket import AsyncJsonWebsocketConsumer
from django.conf import settings

from accounts.models import User
from chat import services as chat
from core.exceptions import ApiError
from core.ratelimit import limit
from core.realtime import user_group
from matching import calls, friend_calls
from matching import service as matching
from matching.models import MatchSession

logger = logging.getLogger(__name__)


def _fresh(user_id) -> User:
    return User.objects.get(id=user_id)


def _session_for(user, session_id) -> MatchSession:
    session = MatchSession.objects.filter(id=session_id).first()
    if session is None or not session.has(user.id):
        raise ApiError("not_found", "Session not found.", 404)
    return session


def _handle(user_id, event: dict) -> dict | None:
    """Runs one client event in a worker thread; returns an optional reply event."""
    user = _fresh(user_id)
    if not user.is_active:
        raise ApiError("account_removed", "This account was removed.", 403)
    from safety.services import effective_status

    if effective_status(user) == User.Status.SUSPENDED and event.get("type") != "ping":
        raise ApiError("account_suspended", "Your account is suspended.", 403)
    kind = event.get("type")
    match kind:
        case "ping":
            matching.touch_presence(user.id)
            return {"type": "pong"}
        case "queue.join":
            limit(f"join:{user.id}", 120, 3600)
            mode = event.get("mode")
            # FR-8 / MN-7: paid filters need accept_charge (after the charge sheet).
            matching.join(
                user,
                mode,
                event.get("filters") or {},
                accept_charge=bool(event.get("accept_charge")),
            )
            return {"type": "queue.joined", "mode": mode}
        case "queue.leave":
            matching.leave(user.id)
            return {"type": "queue.left"}
        case "session.next" | "session.end":
            session = _session_for(user, event.get("session_id"))
            matching.end_session(session.id, user, "next" if kind == "session.next" else "end")
            return None
        case "chat.message":
            chat.send_message(
                event.get("session_id"), user, event.get("body", ""), chat_id=event.get("chat_id")
            )
            return None
        case "chat.seen":
            chat.mark_seen(
                event.get("session_id"), user, event.get("message_id"), chat_id=event.get("chat_id")
            )
            return None
        case "chat.typing":
            chat.typing(event.get("session_id"), user, chat_id=event.get("chat_id"))
            return None
        case "call.invite":
            friend_calls.invite(user, event.get("chat_id"), event.get("mode"))
            return None
        case "call.accept":
            friend_calls.accept(user, event.get("invite_id"))
            return None
        case "call.decline" | "call.cancel":
            friend_calls.decline(user, event.get("invite_id"), cancel=kind == "call.cancel")
            return None
        case "reveal.request" | "reveal.accept":
            calls.request_reveal(event.get("session_id"), user)
            return None
        case "upgrade.request":
            calls.request_upgrade(event.get("session_id"), user)
            return None
        case "upgrade.accept":
            calls.accept_upgrade(event.get("session_id"), user)
            return None
        case "upgrade.decline":
            calls.decline_upgrade(event.get("session_id"), user)
            return None
    raise ApiError("unknown_event", f"Unknown event: {kind}")


class RealtimeConsumer(AsyncJsonWebsocketConsumer):
    """The single authenticated websocket at /ws/ (PRD: Websocket events)."""

    async def connect(self):
        user = self.scope["user"]
        if not user.is_authenticated:
            await self.close(code=4401)
            return
        client = (self.scope.get("client") or ["?"])[0]
        try:
            await sync_to_async(limit, thread_sensitive=False)(
                f"wsconnect:{client}", settings.WS_CONNECTS_PER_IP_PER_MINUTE, 60
            )
        except ApiError:
            await self.close(code=4429)
            return
        self.user_id = user.id
        self.group = user_group(user.id)
        await self.channel_layer.group_add(self.group, self.channel_name)
        await self.accept()
        # Redis only: keep it off Django's single DB thread.
        await sync_to_async(matching.on_connect, thread_sensitive=False)(user.id)

    async def disconnect(self, code):
        if hasattr(self, "group"):
            await self.channel_layer.group_discard(self.group, self.channel_name)
            await database_sync_to_async(matching.on_disconnect)(self.user_id)

    async def receive_json(self, content, **kwargs):
        if not isinstance(content, dict):
            await self.send_json(
                {"type": "error", "code": "invalid", "detail": "Send a JSON object."}
            )
            return
        try:
            reply = await database_sync_to_async(_handle)(self.user_id, content)
        except ApiError as e:
            reply = {
                "type": "error",
                "code": e.error_code,
                "detail": str(e.detail),
                "request": content.get("type"),
                **e.extra,
            }
        except User.DoesNotExist:
            await self.close(code=4401)
            return
        except Exception:
            logger.exception("ws event failed: %s", content.get("type"))
            reply = {"type": "error", "code": "server_error", "detail": "Something went wrong."}
        if reply:
            await self.send_json(reply)

    async def relay(self, message):
        """Server events pushed with core.realtime.send_to_user."""
        await self.send_json(message["event"])
        if message["event"]["type"] == "account.closed":  # suspended or banned (SF-6)
            await self.close(code=4403)
