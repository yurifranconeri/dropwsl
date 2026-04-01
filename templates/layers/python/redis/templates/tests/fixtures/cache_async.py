"""Redis cache fixtures -- async mocks for unit tests."""

from unittest.mock import AsyncMock

import pytest


@pytest.fixture
def fake_redis():
    """Async mock of Redis client -- no real Redis."""
    mock = AsyncMock()
    mock.ping = AsyncMock(return_value=True)
    mock.get = AsyncMock(return_value=None)
    mock.set = AsyncMock(return_value=True)
    mock.delete = AsyncMock(return_value=1)
    return mock
