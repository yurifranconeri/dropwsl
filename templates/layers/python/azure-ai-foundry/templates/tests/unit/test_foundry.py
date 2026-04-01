"""Unit tests for foundry package (client, models, connections)."""

import os
from unittest.mock import MagicMock, patch

import pytest

import foundry.client as client_mod
import foundry.connections as connections_mod
import foundry.models as models_mod


# ---------------------------------------------------------------------------
# client.py — get_project_client
# ---------------------------------------------------------------------------


class TestGetProjectClient:
    """Tests for get_project_client() singleton."""

    def setup_method(self) -> None:
        client_mod._client = None
        client_mod._openai_client = None

    def test_raises_without_endpoint(self) -> None:
        with patch.dict(os.environ, {}, clear=True), pytest.raises(ValueError, match="AZURE_AI_PROJECT_ENDPOINT"):
            client_mod.get_project_client()

    def test_returns_client_with_endpoint(self) -> None:
        with (
            patch.dict(os.environ, {"AZURE_AI_PROJECT_ENDPOINT": "https://test.services.ai.azure.com/api/projects/p1"}),
            patch.object(client_mod, "AIProjectClient") as mock_cls,
            patch.object(client_mod, "get_credential") as mock_cred,
        ):
            mock_cls.return_value = MagicMock()
            mock_cred.return_value = MagicMock()
            client = client_mod.get_project_client()
            assert client is not None
            mock_cls.assert_called_once()

    def test_singleton_returns_same_instance(self) -> None:
        with (
            patch.dict(os.environ, {"AZURE_AI_PROJECT_ENDPOINT": "https://test.services.ai.azure.com/api/projects/p1"}),
            patch.object(client_mod, "AIProjectClient") as mock_cls,
            patch.object(client_mod, "get_credential") as mock_cred,
        ):
            mock_cls.return_value = MagicMock()
            mock_cred.return_value = MagicMock()
            c1 = client_mod.get_project_client()
            c2 = client_mod.get_project_client()
            assert c1 is c2
            mock_cls.assert_called_once()


# ---------------------------------------------------------------------------
# client.py — get_openai_client
# ---------------------------------------------------------------------------


class TestGetOpenaiClient:
    """Tests for get_openai_client() singleton."""

    def setup_method(self) -> None:
        client_mod._client = None
        client_mod._openai_client = None

    def test_returns_openai_client(self) -> None:
        mock_project = MagicMock()
        mock_openai = MagicMock()
        mock_project.get_openai_client.return_value = mock_openai
        with patch.object(client_mod, "get_project_client", return_value=mock_project):
            result = client_mod.get_openai_client()
            assert result is mock_openai
            mock_project.get_openai_client.assert_called_once()

    def test_singleton_returns_same_instance(self) -> None:
        mock_project = MagicMock()
        mock_openai = MagicMock()
        mock_project.get_openai_client.return_value = mock_openai
        with patch.object(client_mod, "get_project_client", return_value=mock_project):
            c1 = client_mod.get_openai_client()
            c2 = client_mod.get_openai_client()
            assert c1 is c2
            mock_project.get_openai_client.assert_called_once()


# ---------------------------------------------------------------------------
# client.py — foundry_health
# ---------------------------------------------------------------------------


class TestFoundryHealth:
    """Tests for foundry_health()."""

    def setup_method(self) -> None:
        client_mod._client = None

    def test_success(self) -> None:
        with patch.object(client_mod, "get_project_client") as mock_get:
            mock_deployment = MagicMock()
            mock_get.return_value.deployments.list.return_value = iter([mock_deployment])
            assert client_mod.foundry_health() is True

    def test_failure(self) -> None:
        with patch.object(client_mod, "get_project_client") as mock_get:
            mock_get.side_effect = ValueError("no endpoint")
            assert client_mod.foundry_health() is False


# ---------------------------------------------------------------------------
# models.py — list_models
# ---------------------------------------------------------------------------


class TestListModels:
    """Tests for list_models()."""

    def _make_deployment(
        self, name: str, model: str, version: str, publisher: str, caps: list[str]
    ) -> MagicMock:
        from azure.ai.projects.models import ModelDeployment

        d = MagicMock(spec=ModelDeployment)
        d.name = name
        d.type = "ModelDeployment"
        d.model_name = model
        d.model_version = version
        d.model_publisher = publisher
        d.capabilities = caps
        d.sku = "GlobalStandard"
        d.connection_name = "default"
        return d

    def test_returns_enriched_list(self) -> None:
        dep = self._make_deployment("gpt-4o", "gpt-4o", "2024-05-13", "OpenAI", ["chat"])
        with patch.object(models_mod, "get_project_client") as mock_get:
            mock_get.return_value.deployments.list.return_value = [dep]
            result = models_mod.list_models()
            assert len(result) == 1
            assert result[0]["name"] == "gpt-4o"
            assert result[0]["model_publisher"] == "OpenAI"
            assert result[0]["capabilities"] == ["chat"]
            assert result[0]["sku"] == "GlobalStandard"

    def test_empty_deployments(self) -> None:
        with patch.object(models_mod, "get_project_client") as mock_get:
            mock_get.return_value.deployments.list.return_value = []
            result = models_mod.list_models()
            assert result == []

    def test_filter_by_publisher(self) -> None:
        with patch.object(models_mod, "get_project_client") as mock_get:
            mock_get.return_value.deployments.list.return_value = []
            models_mod.list_models(model_publisher="OpenAI")
            mock_get.return_value.deployments.list.assert_called_once_with(model_publisher="OpenAI")


# ---------------------------------------------------------------------------
# models.py — get_model
# ---------------------------------------------------------------------------


class TestGetModel:
    """Tests for get_model()."""

    def test_returns_deployment(self) -> None:
        from azure.ai.projects.models import ModelDeployment

        dep = MagicMock(spec=ModelDeployment)
        dep.name = "gpt-4o"
        dep.type = "ModelDeployment"
        dep.model_name = "gpt-4o"
        dep.model_version = "2024-05-13"
        dep.model_publisher = "OpenAI"
        dep.capabilities = ["chat"]
        dep.sku = "GlobalStandard"
        dep.connection_name = "default"

        with patch.object(models_mod, "get_project_client") as mock_get:
            mock_get.return_value.deployments.get.return_value = dep
            result = models_mod.get_model("gpt-4o")
            assert result["name"] == "gpt-4o"

    def test_not_found_raises_key_error(self) -> None:
        with patch.object(models_mod, "get_project_client") as mock_get:
            mock_get.return_value.deployments.get.side_effect = Exception("not found")
            with pytest.raises(KeyError):
                models_mod.get_model("nonexistent")


# ---------------------------------------------------------------------------
# connections.py — list_connections
# ---------------------------------------------------------------------------


class TestListConnections:
    """Tests for list_connections()."""

    def test_returns_list(self) -> None:
        conn = MagicMock()
        conn.name = "openai-default"
        conn.connection_type = "AzureOpenAI"
        conn.target = "https://openai.azure.com"
        with patch.object(connections_mod, "get_project_client") as mock_get:
            mock_get.return_value.connections.list.return_value = [conn]
            result = connections_mod.list_connections()
            assert len(result) == 1
            assert result[0]["name"] == "openai-default"
            assert result[0]["connection_type"] == "AzureOpenAI"

    def test_empty(self) -> None:
        with patch.object(connections_mod, "get_project_client") as mock_get:
            mock_get.return_value.connections.list.return_value = []
            assert connections_mod.list_connections() == []

    def test_filter_by_type(self) -> None:
        with patch.object(connections_mod, "get_project_client") as mock_get:
            mock_get.return_value.connections.list.return_value = []
            connections_mod.list_connections(connection_type="AzureOpenAI")
            mock_get.return_value.connections.list.assert_called_once_with(connection_type="AzureOpenAI")


# ---------------------------------------------------------------------------
# connections.py — get_default_connection
# ---------------------------------------------------------------------------


class TestGetDefaultConnection:
    """Tests for get_default_connection()."""

    def test_returns_default(self) -> None:
        conn = MagicMock()
        conn.name = "default-openai"
        conn.connection_type = "AzureOpenAI"
        conn.target = "https://openai.azure.com"
        with patch.object(connections_mod, "get_project_client") as mock_get:
            mock_get.return_value.connections.get_default.return_value = conn
            result = connections_mod.get_default_connection("AzureOpenAI")
            assert result["name"] == "default-openai"

    def test_not_found_raises_key_error(self) -> None:
        with patch.object(connections_mod, "get_project_client") as mock_get:
            mock_get.return_value.connections.get_default.side_effect = Exception("no default")
            with pytest.raises(KeyError):
                connections_mod.get_default_connection("NonExistent")
