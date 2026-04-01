"""Ponto de entrada da aplicação — demonstra CRUD com PostgreSQL."""

from {{IMPORT_PREFIX}}db import service
from {{IMPORT_PREFIX}}db.engine import engine, get_session
from {{IMPORT_PREFIX}}db.models import Base


def main() -> None:
    # Create tables (idempotent)
    Base.metadata.create_all(bind=engine)

    session = next(get_session())
    try:
        # Create a sample item
        item = service.create_item(session, name="hello world")
        print(f"Created: {item!r}")  # noqa: T201

        # List items
        items = service.list_items(session)
        print(f"Total: {len(items)} item(s)")  # noqa: T201

        # Get by ID
        found = service.get_item(session, item.id)
        print(f"Found: {found!r}")  # noqa: T201
    finally:
        session.close()


if __name__ == "__main__":
    main()
