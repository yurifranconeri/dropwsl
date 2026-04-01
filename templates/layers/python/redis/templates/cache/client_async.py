"""Redis client — async para FastAPI."""

import os
from collections.abc import AsyncGenerator

import redis.asyncio as aioredis

REDIS_URL = os.getenv("REDIS_URL", "redis://redis:6379/0")

redis_client: aioredis.Redis = aioredis.from_url(
    REDIS_URL,
    decode_responses=True,
)


async def get_redis() -> AsyncGenerator[aioredis.Redis, None]:
    """FastAPI dependency -- injects Redis client."""
    yield redis_client


async def redis_health() -> bool:
    """Returns True if Redis responds with PONG."""
    try:
        return bool(await redis_client.ping())  # type: ignore[misc]
    except (aioredis.ConnectionError, aioredis.TimeoutError, OSError):
        return False
