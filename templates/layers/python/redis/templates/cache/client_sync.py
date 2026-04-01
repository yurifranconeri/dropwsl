"""Redis client — sync."""

import os

import redis

REDIS_URL = os.getenv("REDIS_URL", "redis://redis:6379/0")

redis_client: redis.Redis = redis.from_url(
    REDIS_URL,
    decode_responses=True,
)


def get_redis() -> redis.Redis:
    """Returns Redis client."""
    return redis_client


def redis_health() -> bool:
    """Returns True if Redis responds with PONG."""
    try:
        return bool(redis_client.ping())
    except (redis.ConnectionError, redis.TimeoutError, OSError):
        return False
