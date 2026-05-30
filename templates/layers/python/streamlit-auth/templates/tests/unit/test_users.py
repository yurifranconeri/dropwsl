"""Unit tests for the users package — store and password helpers."""

from __future__ import annotations

from pathlib import Path
from typing import cast

import pytest

from users.store import (
    User,
    YamlStore,
    hash_password,
    verify_password,
)


@pytest.fixture
def store(tmp_path: Path) -> YamlStore:
    return YamlStore(path=tmp_path / "credentials.yaml")


def test_hash_password_roundtrip() -> None:
    h = hash_password("correct horse battery staple")
    assert verify_password("correct horse battery staple", h)
    assert not verify_password("wrong password", h)


def test_hash_password_rejects_empty() -> None:
    with pytest.raises(ValueError):
        hash_password("")


def test_verify_password_handles_invalid_hash() -> None:
    assert verify_password("any", "not-a-bcrypt-hash") is False
    assert verify_password("", "any") is False
    assert verify_password("any", "") is False


def test_yaml_store_upsert_and_get(store: YamlStore) -> None:
    user = User(
        username="alice",
        name="Alice",
        email="alice@example.com",
        password_hash=hash_password("s3cret-pass"),
    )
    store.upsert(user)
    fetched = store.get("alice")
    assert fetched is not None
    assert fetched["username"] == "alice"
    assert fetched["name"] == "Alice"
    assert fetched["email"] == "alice@example.com"
    assert "password_hash" in fetched


def test_yaml_store_list_omits_password_hash(store: YamlStore) -> None:
    store.upsert(
        User(
            username="bob",
            name="Bob",
            email="bob@example.com",
            password_hash=hash_password("anotherpass"),
        )
    )
    listed = store.list()
    assert len(listed) == 1
    assert "password_hash" not in listed[0]
    assert listed[0]["username"] == "bob"


def test_yaml_store_verify(store: YamlStore) -> None:
    store.upsert(
        User(
            username="carol",
            name="Carol",
            email="carol@example.com",
            password_hash=hash_password("correct-pass"),
        )
    )
    assert store.verify("carol", "correct-pass") is True
    assert store.verify("carol", "wrong-pass") is False
    assert store.verify("nobody", "anything") is False


def test_yaml_store_delete(store: YamlStore) -> None:
    store.upsert(
        User(
            username="dave",
            name="Dave",
            email="dave@example.com",
            password_hash=hash_password("pass1234"),
        )
    )
    assert store.delete("dave") is True
    assert store.get("dave") is None
    assert store.delete("dave") is False  # idempotent


def test_yaml_store_upsert_rejects_missing_username(store: YamlStore) -> None:
    with pytest.raises(ValueError):
        store.upsert(cast(User, {"name": "x", "password_hash": hash_password("p")}))


def test_yaml_store_upsert_rejects_missing_hash(store: YamlStore) -> None:
    with pytest.raises(ValueError):
        store.upsert(cast(User, {"username": "x", "name": "x"}))


def test_yaml_store_get_returns_none_for_missing_file(tmp_path: Path) -> None:
    s = YamlStore(path=tmp_path / "does-not-exist.yaml")
    assert s.get("nobody") is None
    assert s.list() == []
