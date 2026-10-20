import time

import pytest
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import AccessToken

from matching import service as matching
from matching.models import MatchSession
from safety.models import Block

pytestmark = pytest.mark.django_db


def client_for(user):
    c = APIClient()
    c.credentials(HTTP_AUTHORIZATION=f"Bearer {AccessToken.for_user(user)}")
    return c


@pytest.fixture
def session(make_user, redis_db, events):
    a, b = make_user("Ada"), make_user("Kwame")
    matching.join(a, "text")
    matching.join(b, "text")
    (s,) = matching.run_tick()
    return s, a, b


def test_sf5_block_ends_the_chat_and_they_are_never_matched_again(session, events):
    s, a, b = session
    res = client_for(a).post("/api/v1/blocks", {"session_id": str(s.id)}, format="json")
    assert res.status_code == 201
    s.refresh_from_db()
    assert s.end_reason == "blocked"
    assert events.of(b, "session.ended")[-1]["reason"] == "peer_left"

    future = time.time() + 2 * 24 * 3600  # past the 24 h re-pair window
    matching.join(a, "text", now=future - 60)
    matching.join(b, "text", now=future - 60)
    assert matching.run_tick(now=future) == []


def test_block_needs_to_be_your_session(session, make_user):
    s, _, _ = session
    res = client_for(make_user("Eve")).post(
        "/api/v1/blocks", {"session_id": str(s.id)}, format="json"
    )
    assert res.status_code == 404


def test_unblock(session):
    s, a, _ = session
    block_id = (
        client_for(a).post("/api/v1/blocks", {"session_id": str(s.id)}, format="json").json()["id"]
    )
    assert client_for(a).delete(f"/api/v1/blocks/{block_id}").status_code == 204
    assert not Block.objects.exists()


def test_session_detail_returns_messages_to_participants_only(session, make_user, events):
    s, a, _ = session
    from chat.services import send_message

    send_message(s.id, a, "hi")
    body = client_for(a).get(f"/api/v1/sessions/{s.id}").json()
    assert body["peer"]["first_name"] == "Kwame" and body["messages"][0]["body"] == "hi"
    assert client_for(make_user("Eve")).get(f"/api/v1/sessions/{s.id}").status_code == 404
    assert MatchSession.objects.count() == 1
