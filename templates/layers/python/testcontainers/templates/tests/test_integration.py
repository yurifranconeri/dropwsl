"""Integration tests -- real PostgreSQL via testcontainers."""

import pytest

from {{IMPORT_PREFIX}}db import service


@pytest.mark.integration
def test_create_and_get_item(db_session) -> None:
    """End-to-end CRUD with real Postgres."""
    item = service.create_item(db_session, name="integration")
    assert item.id is not None

    found = service.get_item(db_session, item.id)
    assert found is not None
    assert found.name == "integration"


@pytest.mark.integration
def test_delete_nonexistent_returns_false(db_session) -> None:
    """Delete of nonexistent item returns False, does not raise."""
    assert service.delete_item(db_session, 99999) is False


@pytest.mark.integration
def test_list_items_empty(db_session) -> None:
    """Empty list when no items exist (rollback between tests ensures isolation)."""
    items = service.list_items(db_session)
    assert items == []
