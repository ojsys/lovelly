import time

from core.exceptions import ApiError
from core.redis import get_redis


def limit(key: str, max_hits: int, window_seconds: int, detail="Slow down a little.") -> None:
    """Fixed-window rate limit (NFR: rate limits on auth, reports and chat). Raises 429."""
    window = int(time.time() // window_seconds)
    redis_key = f"rl:{key}:{window}"
    r = get_redis()
    hits = r.incr(redis_key)
    if hits == 1:
        r.expire(redis_key, window_seconds * 2)
    if hits > max_hits:
        retry = int(window_seconds - time.time() % window_seconds) + 1
        raise ApiError("throttled", detail, 429, retry_after=retry)
