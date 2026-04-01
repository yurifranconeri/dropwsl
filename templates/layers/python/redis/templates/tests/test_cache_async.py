"""Unit tests for Redis client and /cache routes -- no real Redis."""

from unittest.mock import AsyncMock, patch

import pytest
from httpx import ASGITransport, AsyncClient

from {{IMPORT_PREFIX}}cache.client import get_redis, redis_health
from {{IMPORT_PREFIX}}main import app


@pytest.mark.asyncio
async def test_redis_health_ok() -> None:
    """redis_health returns True when Redis responds with PONG."""
    with patch("{{IMPORT_PREFIX}}cache.client.redis_client") as mock_redis:
        mock_redis.ping = AsyncMock(return_value=True)
        result = await redis_health()
        assert result is True


@pytest.mark.asyncio
async def test_redis_health_fail() -> None:
    """redis_health returns False when Redis is not reachable."""
    with patch("{{IMPORT_PREFIX}}cache.client.redis_client") as mock_redis:
        mock_redis.ping = AsyncMock(side_effect=ConnectionError("refused"))
        result = await redis_health()
        assert result is False


@pytest.mark.asyncio
async def test_cache_set_and_get() -> None:
    """PUT /cache/{key} writes and GET /cache/{key} reads the value."""
    store: dict[str, str] = {}
    mock_redis = AsyncMock()
    mock_redis.set = AsyncMock(side_effect=lambda k, v, **kw: store.update({k: v}))
    mock_redis.get = AsyncMock(side_effect=lambda k: store.get(k))

    async def override_get_redis():  # noqa: ANN202
        yield mock_redis

    app.dependency_overrides[get_redis] = override_get_redis

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        resp = await ac.put("/cache/greeting", params={"value": "hello"})
        assert resp.status_code == 200
        assert resp.json() == {"key": "greeting", "value": "hello"}

        resp = await ac.get("/cache/greeting")
        assert resp.status_code == 200
        assert resp.json() == {"key": "greeting", "value": "hello"}

    app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_cache_get_missing_key() -> None:
    """GET /cache/{key} returns null when key does not exist."""
    mock_redis = AsyncMock()
    mock_redis.get = AsyncMock(return_value=None)

    async def override_get_redis():  # noqa: ANN202
        yield mock_redis

    app.dependency_overrides[get_redis] = override_get_redis

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        resp = await ac.get("/cache/nonexistent")
        assert resp.status_code == 200
        assert resp.json() == {"key": "nonexistent", "value": None}

    app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_cache_delete() -> None:
    """DELETE /cache/{key} returns 204."""
    mock_redis = AsyncMock()
    mock_redis.delete = AsyncMock(return_value=1)

    async def override_get_redis():  # noqa: ANN202
        yield mock_redis

    app.dependency_overrides[get_redis] = override_get_redis

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        resp = await ac.delete("/cache/some-key")
        assert resp.status_code == 204

    app.dependency_overrides.clear()
