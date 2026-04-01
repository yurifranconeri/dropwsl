"""Database fixtures -- SQLite in-memory for unit tests."""

from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from {{IMPORT_PREFIX}}db.engine import get_session
from {{IMPORT_PREFIX}}db.models import Base
from {{IMPORT_PREFIX}}main import app

_test_engine = create_engine("sqlite:///:memory:")
_TestSession = sessionmaker(bind=_test_engine, expire_on_commit=False)


@pytest.fixture
def db_engine():
    """SQLite in-memory engine -- creates tables before, cleans up after."""
    Base.metadata.create_all(bind=_test_engine)
    yield _test_engine
    Base.metadata.drop_all(bind=_test_engine)


@pytest.fixture
def db_session(db_engine):
    """Session with automatic rollback."""
    session = _TestSession()
    yield session
    session.close()


@pytest.fixture
def client_db(db_engine):
    """TestClient with SQLite database -- for tests that do HTTP + DB."""

    def override_get_session():
        session = _TestSession()
        try:
            yield session
        finally:
            session.close()

    app.dependency_overrides[get_session] = override_get_session
    with patch("{{IMPORT_PREFIX}}main.engine", _test_engine), TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()
