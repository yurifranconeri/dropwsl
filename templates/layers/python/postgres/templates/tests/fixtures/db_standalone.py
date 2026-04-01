"""Database fixtures -- SQLite in-memory for unit tests."""

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from {{IMPORT_PREFIX}}db.models import Base

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
