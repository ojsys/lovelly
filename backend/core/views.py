import logging

import redis
from django.conf import settings
from django.db import connection
from drf_spectacular.utils import extend_schema, inline_serializer
from rest_framework import serializers, status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

logger = logging.getLogger(__name__)


def _check_db() -> bool:
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
        return True
    except Exception:
        logger.exception("health: database check failed")
        return False


def _check_redis() -> bool:
    try:
        return bool(redis.Redis.from_url(settings.REDIS_URL, socket_timeout=2).ping())
    except Exception:
        logger.exception("health: redis check failed")
        return False


class HealthView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]

    @extend_schema(
        responses=inline_serializer(
            "Health",
            {
                "status": serializers.CharField(),
                "db": serializers.BooleanField(),
                "redis": serializers.BooleanField(),
            },
        )
    )
    def get(self, request):
        db_ok, redis_ok = _check_db(), _check_redis()
        ok = db_ok and redis_ok
        return Response(
            {"status": "ok" if ok else "degraded", "db": db_ok, "redis": redis_ok},
            status=status.HTTP_200_OK if ok else status.HTTP_503_SERVICE_UNAVAILABLE,
        )
