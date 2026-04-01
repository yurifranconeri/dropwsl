
def _azure_credential_available() -> bool:
    """Check if Azure credentials are available (cached, not per-call)."""
    try:
        from azure.identity import DefaultAzureCredential
        DefaultAzureCredential().get_token("https://management.azure.com/.default")
        return True
    except Exception:
        return False


_AZURE_AVAILABLE: bool | None = None


@pytest.fixture
def requires_azure():
    """Skip test if Azure credentials are not available."""
    global _AZURE_AVAILABLE  # noqa: PLW0603
    if _AZURE_AVAILABLE is None:
        _AZURE_AVAILABLE = _azure_credential_available()
    if not _AZURE_AVAILABLE:
        pytest.skip("Azure credentials not available -- run 'az login'")
