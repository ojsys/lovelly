import asyncio
import contextvars
import json
from contextlib import contextmanager
from datetime import datetime

from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from django.core.serializers.json import DjangoJSONEncoder

# Events buffered by `batched()`; None when sending immediately.
_buffer: contextvars.ContextVar[list | None] = contextvars.ContextVar(
    "realtime_buffer", default=None
)


def user_group(user_id) -> str:
    return f"user.{user_id}"


class _Encoder(DjangoJSONEncoder):
    """Full-precision datetimes (Django's encoder cuts them to ms; times are paging cursors)."""

    def default(self, o):
        if isinstance(o, datetime):
            return o.isoformat()
        return super().default(o)


def json_safe(payload: dict) -> dict:
    """Plain JSON types only: the Redis layer (msgpack) can't carry datetimes or UUIDs."""
    return json.loads(json.dumps(payload, cls=_Encoder))


def _message(user_id, event_type, payload):
    event = {"type": event_type, **json_safe(payload)}
    return user_group(user_id), {"type": "relay", "event": event}


def send_to_user(user_id, event_type: str, payload: dict) -> None:
    """Push a server event to every websocket the user has open (PRD: Websocket events)."""
    buffered = _buffer.get()
    if buffered is not None:
        buffered.append(_message(user_id, event_type, payload))
        return
    async_to_sync(get_channel_layer().group_send)(*_message(user_id, event_type, payload))


async def _send_all(messages):
    layer = get_channel_layer()
    await asyncio.gather(*(layer.group_send(group, msg) for group, msg in messages))


@contextmanager
def batched():
    """Collects events and sends them together on exit.

    Each async_to_sync call from sync code starts a fresh event loop (and Redis
    connections), so the matcher sends a whole tick's events in one go.
    """
    token = _buffer.set([])
    try:
        yield
    finally:
        messages = _buffer.get()
        _buffer.reset(token)
        if messages:
            async_to_sync(_send_all)(messages)
