"""Database engine e session management."""

import os
from collections.abc import Generator

from sqlalchemy import create_engine, text
from sqlalchemy.orm import Session, sessionmaker

DATABASE_URL = os.getenv("DATABASE_URL")
if not DATABASE_URL:
    raise RuntimeError(
        "DATABASE_URL not configured. "
        "Set it in .env (e.g.: DATABASE_URL=postgresql+psycopg://user:pass@host:5432/dbname)"
    )

# SQLite uses SingletonThreadPool, which rejects QueuePool kwargs.
# Condition pool tuning to non-SQLite dialects so unit tests (SQLite in-memory)
# and production (Postgres) share the same engine module.
_pool_kwargs: dict = {}
if not DATABASE_URL.startswith("sqlite"):
    _pool_kwargs = {"pool_size": 5, "max_overflow": 10}

engine = create_engine(
    DATABASE_URL,
    pool_pre_ping=True,
    echo=False,
    **_pool_kwargs,
)

SessionLocal = sessionmaker(bind=engine, expire_on_commit=False)


def db_health() -> bool:
    """Returns True when PostgreSQL accepts a simple query."""
    try:
        with engine.connect() as connection:
            connection.execute(text("SELECT 1"))
        return True
    except Exception:
        return False


def get_session() -> Generator[Session, None, None]:
    """FastAPI dependency -- injects session and rolls back on error."""
    session = SessionLocal()
    try:
        yield session
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()
