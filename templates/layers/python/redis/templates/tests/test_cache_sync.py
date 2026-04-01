"""Unit tests for Redis client -- no real Redis."""

from unittest.mock import MagicMock, patch

from {{IMPORT_PREFIX}}cache.client import redis_health


def test_redis_health_ok() -> None:
    """redis_health returns True when Redis responds with PONG."""
    with patch("{{IMPORT_PREFIX}}cache.client.redis_client") as mock_redis:
        mock_redis.ping = MagicMock(return_value=True)
        result = redis_health()
        assert result is True


def test_redis_health_fail() -> None:
    """redis_health returns False when Redis is not reachable."""
    with patch("{{IMPORT_PREFIX}}cache.client.redis_client") as mock_redis:
        mock_redis.ping = MagicMock(side_effect=ConnectionError("refused"))
        result = redis_health()
        assert result is False
