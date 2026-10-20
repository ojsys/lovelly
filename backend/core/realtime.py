import asyncio
import contextvars
from contextlib import contextmanager

from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer

# Events buffered by `batched()`; None when sending immediately.
_buffer: contextvars.ContextVar[list | None] = contextvars.ContextVar(
    "realtime_buffer", default=None
)


def user_group(user_id) -> str:
    return f"user.{user_id}"


def _message(user_id, event_type, payload):
    return user_group(user_id), {"type": "relay", "event": {"type": event_type, **payload}}


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
