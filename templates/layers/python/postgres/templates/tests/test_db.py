"""Unit tests for the service layer -- no database."""

from unittest.mock import MagicMock

from {{IMPORT_PREFIX}}db.models import ItemModel
from {{IMPORT_PREFIX}}db.service import create_item, delete_item, get_item


def test_create_item() -> None:
    """create_item should call session.add and session.commit."""
    session = MagicMock()
    session.refresh = MagicMock(side_effect=lambda obj: setattr(obj, "id", 1))

    result = create_item(session, name="test")

    session.add.assert_called_once()
    session.commit.assert_called_once()
    assert isinstance(result, ItemModel)
    assert result.name == "test"


def test_get_item() -> None:
    """get_item should call session.get with model and ID."""
    session = MagicMock()
    session.get.return_value = ItemModel(id=1, name="found")

    result = get_item(session, 1)

    session.get.assert_called_once_with(ItemModel, 1)
    assert result is not None
    assert result.name == "found"


def test_get_item_not_found() -> None:
    """get_item should return None when item does not exist."""
    session = MagicMock()
    session.get.return_value = None

    result = get_item(session, 999)

    assert result is None


def test_delete_item_exists() -> None:
    """delete_item should return True and call session.delete when item exists."""
    session = MagicMock()
    item = ItemModel(id=1, name="to-delete")
    session.get.return_value = item

    result = delete_item(session, 1)

    assert result is True
    session.delete.assert_called_once_with(item)
    session.commit.assert_called_once()


def test_delete_item_not_found() -> None:
    """delete_item should return False when item does not exist."""
    session = MagicMock()
    session.get.return_value = None

    result = delete_item(session, 999)

    assert result is False
    session.delete.assert_not_called()
