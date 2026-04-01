"""Smoke tests -- post-deploy connectivity validation."""

import pytest
from sqlalchemy import text


@pytest.mark.smoke
def test_db_connectivity(db_session) -> None:
    """Database is reachable and responds."""
    result = db_session.execute(text("SELECT 1")).scalar()
    assert result == 1
