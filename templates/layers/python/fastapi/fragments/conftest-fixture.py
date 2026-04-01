

@pytest.fixture
def client():
    """TestClient for tests -- no real HTTP server."""
    return TestClient(app)
