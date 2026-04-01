"""Service layer -- CRUD functions with injected Session."""

from sqlalchemy import select
from sqlalchemy.orm import Session

from .models import ItemModel


def create_item(session: Session, *, name: str, description: str | None = None) -> ItemModel:
    """Creates an item and commits."""
    item = ItemModel(name=name, description=description)
    session.add(item)
    session.commit()
    session.refresh(item)
    return item


def get_item(session: Session, item_id: int) -> ItemModel | None:
    """Gets item by ID. Returns None if not found."""
    return session.get(ItemModel, item_id)


def list_items(session: Session, *, limit: int = 100) -> list[ItemModel]:
    """Lists items with limit."""
    stmt = select(ItemModel).limit(limit)
    return list(session.scalars(stmt).all())


def delete_item(session: Session, item_id: int) -> bool:
    """Deletes item. Returns True if it existed."""
    item = session.get(ItemModel, item_id)
    if item is None:
        return False
    session.delete(item)
    session.commit()
    return True
