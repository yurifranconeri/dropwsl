"""Smoke tests -- post-deploy connectivity validation."""

import pytest
from sqlalchemy import text


@pytest.mark.smoke
def test_db_connectivity(db_session) -> None:
    """Database is reachable and responds."""
    result = db_session.execute(text("SELECT 1")).scalar()
    assert result == 1


@pytest.mark.smoke
def test_health_endpoint(client) -> None:
    """App responds and is healthy."""
    response = client.get("/health")
    assert response.status_code == 200
