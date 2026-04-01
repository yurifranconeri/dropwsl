
def _foundry_endpoint_available() -> bool:
    """Check if Foundry project endpoint is configured."""
    import os
    return bool(os.environ.get("AZURE_AI_PROJECT_ENDPOINT", ""))


_FOUNDRY_AVAILABLE: bool | None = None


@pytest.fixture
def requires_foundry():
    """Skip test if Foundry endpoint is not configured."""
    global _FOUNDRY_AVAILABLE  # noqa: PLW0603
    if _FOUNDRY_AVAILABLE is None:
        _FOUNDRY_AVAILABLE = _foundry_endpoint_available()
    if not _FOUNDRY_AVAILABLE:
        pytest.skip("AZURE_AI_PROJECT_ENDPOINT not set")
