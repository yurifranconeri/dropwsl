"""Cache package — re-exports para conveniência."""

from .client import get_redis, redis_client

__all__ = ["get_redis", "redis_client"]
