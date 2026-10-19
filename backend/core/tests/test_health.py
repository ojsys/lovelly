from unittest import mock

import pytest
from django.urls import reverse

pytestmark = pytest.mark.django_db


def test_health_ok(client):
    response = client.get(reverse("health"))
    assert response.status_code == 200
    assert response.json() == {"status": "ok", "db": True, "redis": True}


def test_health_returns_503_when_redis_down(client):
    with mock.patch("core.views._check_redis", return_value=False):
        response = client.get(reverse("health"))
    assert response.status_code == 503
    assert response.json()["status"] == "degraded"


def test_health_needs_no_auth(client):
    assert client.get("/api/v1/health").status_code == 200


def test_openapi_schema_is_served(client):
    assert client.get("/api/v1/schema/").status_code == 200
