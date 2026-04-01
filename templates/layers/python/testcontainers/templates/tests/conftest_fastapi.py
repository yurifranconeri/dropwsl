"""Pytest fixtures -- testcontainers for ephemeral PostgreSQL."""

from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from testcontainers.postgres import PostgresContainer

from {{IMPORT_PREFIX}}db.engine import get_session
from {{IMPORT_PREFIX}}db.models import Base
from {{IMPORT_PREFIX}}main import app


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


@pytest.fixture
def client(db_session, db_engine):
    """TestClient with testcontainer Session injected."""

    def override_get_session():
        yield db_session

    app.dependency_overrides[get_session] = override_get_session
    # Patcha engine no main para que o lifespan use o testcontainer
    with patch("{{PATCH_TARGET}}", db_engine), TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()
