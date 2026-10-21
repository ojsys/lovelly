"""Two clients over the real /ws/ consumer and channel layer (M2 acceptance, in-process)."""

import pytest
from channels.db import database_sync_to_async
from channels.testing import WebsocketCommunicator
from rest_framework_simplejwt.tokens import AccessToken

from lovelly.asgi import application
from matching import service

pytestmark = [pytest.mark.django_db(transaction=True), pytest.mark.asyncio]

HEADERS = [(b"origin", b"http://localhost")]


async def connect(user):
    token = await database_sync_to_async(lambda: str(AccessToken.for_user(user)))()
    ws = WebsocketCommunicator(application, f"/ws/?token={token}", headers=HEADERS)
    connected, _ = await ws.connect()
    assert connected
    return ws


async def next_event(ws, event_type):
    while True:
        event = await ws.receive_json_from(timeout=3)
        if event["type"] == event_type:
            return event


async def test_two_clients_match_chat_and_next(make_user, redis_db):
    a = await database_sync_to_async(make_user)("Ada", interests=["football"])
    b = await database_sync_to_async(make_user)("Kwame", interests=["football"])
    wa, wb = await connect(a), await connect(b)

    await wa.send_json_to({"type": "queue.join", "mode": "text", "filters": {}})
    await wb.send_json_to({"type": "queue.join", "mode": "text"})
    assert (await next_event(wa, "queue.joined"))["mode"] == "text"
    await next_event(wb, "queue.joined")

    await database_sync_to_async(service.run_tick)()
    found_a = await next_event(wa, "match.found")
    found_b = await next_event(wb, "match.found")
    assert found_a["session_id"] == found_b["session_id"]
    assert found_a["peer"]["shared_interests"] == ["Football"]
    session_id = found_a["session_id"]

    await wa.send_json_to({"type": "chat.message", "session_id": session_id, "body": "Hey!"})
    received = await next_event(wb, "chat.message")
    assert received["message"]["body"] == "Hey!"
    await wb.send_json_to({"type": "chat.typing", "session_id": session_id})
    await next_event(wa, "chat.typing")
    await wb.send_json_to(
        {"type": "chat.seen", "session_id": session_id, "message_id": received["message"]["id"]}
    )
    assert (await next_event(wa, "chat.seen"))["message_id"] == received["message"]["id"]

    await wa.send_json_to({"type": "session.next", "session_id": session_id})
    assert (await next_event(wb, "session.ended"))["reason"] == "peer_next"
    assert (await next_event(wa, "session.ended"))["reason"] == "next"
    assert await database_sync_to_async(service.is_queued)(a.id)

    await wa.disconnect()
    await wb.disconnect()


async def test_errors_come_back_as_error_events(make_user, redis_db):
    user = await database_sync_to_async(make_user)(verified=False)
    ws = await connect(user)
    await ws.send_json_to({"type": "queue.join", "mode": "video"})
    error = await next_event(ws, "error")
    assert (error["code"], error["request"]) == ("not_verified", "queue.join")
    await ws.send_json_to({"type": "bogus"})
    assert (await next_event(ws, "error"))["code"] == "unknown_event"
    await ws.disconnect()
