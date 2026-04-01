"""Tests for the FastAPI app -- uses client fixture (conftest.py)."""


def test_health(client) -> None:
    """GET /health should return 200 with status ok."""
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_root(client) -> None:
    """GET / should return 200 with message."""
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert "message" in data
