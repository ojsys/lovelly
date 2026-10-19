import pytest
from channels.testing import WebsocketCommunicator
from rest_framework_simplejwt.tokens import AccessToken

from accounts.models import User
from korram.asgi import application

pytestmark = [pytest.mark.django_db(transaction=True), pytest.mark.asyncio]

HEADERS = [(b"origin", b"http://localhost")]


async def test_ws_rejects_anonymous():
    comm = WebsocketCommunicator(application, "/ws/", headers=HEADERS)
    connected, code = await comm.connect()
    assert not connected
    assert code == 4401


async def test_ws_accepts_valid_jwt():
    from channels.db import database_sync_to_async

    user = await database_sync_to_async(User.objects.create_user)("+2348030000001")
    token = str(AccessToken.for_user(user))
    comm = WebsocketCommunicator(application, f"/ws/?token={token}", headers=HEADERS)
    connected, _ = await comm.connect()
    assert connected
    await comm.disconnect()
