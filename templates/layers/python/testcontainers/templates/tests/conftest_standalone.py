"""Pytest fixtures -- testcontainers for ephemeral PostgreSQL."""

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from testcontainers.postgres import PostgresContainer

from {{IMPORT_PREFIX}}db.models import Base


@pytest.fixture(scope="session")
def postgres_container():
    """Starts ephemeral PostgreSQL container -- once per test session."""
    with PostgresContainer("postgres:16-alpine", driver="psycopg") as pg:
        yield pg


@pytest.fixture(scope="session")
def db_engine(postgres_container):
    """SQLAlchemy engine connected to the container."""
    engine = create_engine(postgres_container.get_connection_url())
    Base.metadata.create_all(bind=engine)
    return engine


@pytest.fixture
def db_session(db_engine):
    """Isolated session per test -- automatic rollback after each test."""
    connection = db_engine.connect()
    transaction = connection.begin()
    session = Session(bind=connection)
    yield session
    session.close()
    transaction.rollback()
    connection.close()
