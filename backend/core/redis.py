from functools import cache

import redis
from django.conf import settings


@cache
def get_redis() -> redis.Redis:
    """Shared client for short-lived state: queue, presence, active sessions (PRD: Data model)."""
    return redis.Redis.from_url(settings.REDIS_URL, decode_responses=True)
