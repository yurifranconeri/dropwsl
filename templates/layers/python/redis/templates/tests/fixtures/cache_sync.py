"""Redis cache fixtures -- sync mocks for unit tests."""

from unittest.mock import MagicMock

import pytest


@pytest.fixture
def fake_redis():
    """Sync mock of Redis client -- no real Redis."""
    mock = MagicMock()
    mock.ping = MagicMock(return_value=True)
    mock.get = MagicMock(return_value=None)
    mock.set = MagicMock(return_value=True)
    mock.delete = MagicMock(return_value=1)
    return mock
