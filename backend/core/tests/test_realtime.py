import uuid

import msgpack
from django.utils import timezone

from core.realtime import _message


def test_events_carry_plain_json_so_the_redis_layer_can_send_them():
    """M5 bug: friend.request carried a datetime, and the msgpack layer raised a 500."""
    at, uid = timezone.now(), uuid.uuid4()
    group, message = _message("u1", "friend.request", {"request": {"id": uid, "created_at": at}})
    assert group == "user.u1"
    event = message["event"]
    assert event == {
        "type": "friend.request",
        "request": {"id": str(uid), "created_at": at.isoformat()},
    }
    msgpack.packb(message)  # what channels_redis does
