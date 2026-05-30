"""Unit tests for keyvault package (client, secrets)."""

import os
from unittest.mock import MagicMock, patch

import pytest

import keyvault.client as client_mod
import keyvault.secrets as secrets_mod


# ---------------------------------------------------------------------------
# client.py — get_secret_client
# ---------------------------------------------------------------------------


class TestGetSecretClient:
    def setup_method(self) -> None:
        client_mod._client = None

    def test_raises_without_url(self) -> None:
        with patch.dict(os.environ, {}, clear=True), pytest.raises(ValueError, match="AZURE_KEYVAULT_URL"):
            client_mod.get_secret_client()

    def test_returns_client_with_url(self) -> None:
        with (
            patch.dict(os.environ, {"AZURE_KEYVAULT_URL": "https://v.vault.azure.net/"}),
            patch.object(client_mod, "SecretClient") as mock_cls,
            patch.object(client_mod, "get_credential") as mock_cred,
        ):
            mock_cls.return_value = MagicMock()
            mock_cred.return_value = MagicMock()
            assert client_mod.get_secret_client() is not None
            mock_cls.assert_called_once()

    def test_singleton(self) -> None:
        with (
            patch.dict(os.environ, {"AZURE_KEYVAULT_URL": "https://v.vault.azure.net/"}),
            patch.object(client_mod, "SecretClient") as mock_cls,
            patch.object(client_mod, "get_credential"),
        ):
            mock_cls.return_value = MagicMock()
            c1 = client_mod.get_secret_client()
            c2 = client_mod.get_secret_client()
            assert c1 is c2
            mock_cls.assert_called_once()


class TestKeyvaultHealth:
    def setup_method(self) -> None:
        client_mod._client = None

    def test_success(self) -> None:
        with patch.object(client_mod, "get_secret_client") as mock_get:
            mock_get.return_value.list_properties_of_secrets.return_value = iter([MagicMock()])
            assert client_mod.keyvault_health() is True

    def test_failure(self) -> None:
        with patch.object(client_mod, "get_secret_client") as mock_get:
            mock_get.side_effect = ValueError("no url")
            assert client_mod.keyvault_health() is False


# ---------------------------------------------------------------------------
# secrets.py — list_secrets
# ---------------------------------------------------------------------------


def _fake_props(name: str, enabled: bool = True, content_type: str | None = None) -> MagicMock:
    p = MagicMock()
    p.name = name
    p.id = f"https://v.vault.azure.net/secrets/{name}/abc"
    p.version = "abc"
    p.enabled = enabled
    p.content_type = content_type
    p.tags = None
    p.expires_on = None
    p.created_on = None
    p.updated_on = None
    return p


class TestListSecrets:
    def setup_method(self) -> None:
        client_mod._client = None

    def test_returns_metadata(self) -> None:
        fake = [_fake_props("a"), _fake_props("b")]
        with patch.object(secrets_mod, "get_secret_client") as mock_get:
            mock_get.return_value.list_properties_of_secrets.return_value = iter(fake)
            out = secrets_mod.list_secrets()
            assert [s["name"] for s in out] == ["a", "b"]
            for s in out:
                assert "value" not in s

    def test_filters_disabled_when_enabled_only(self) -> None:
        fake = [_fake_props("a", enabled=True), _fake_props("b", enabled=False)]
        with patch.object(secrets_mod, "get_secret_client") as mock_get:
            mock_get.return_value.list_properties_of_secrets.return_value = iter(fake)
            out = secrets_mod.list_secrets(enabled_only=True)
            assert [s["name"] for s in out] == ["a"]

    def test_includes_disabled_when_enabled_only_false(self) -> None:
        fake = [_fake_props("a", enabled=True), _fake_props("b", enabled=False)]
        with patch.object(secrets_mod, "get_secret_client") as mock_get:
            mock_get.return_value.list_properties_of_secrets.return_value = iter(fake)
            out = secrets_mod.list_secrets(enabled_only=False)
            assert [s["name"] for s in out] == ["a", "b"]


# ---------------------------------------------------------------------------
# secrets.py — get_secret
# ---------------------------------------------------------------------------


class TestGetSecret:
    def setup_method(self) -> None:
        client_mod._client = None

    def _mock_secret(self, name: str = "mysecret", value: str = "supersecret") -> MagicMock:
        secret = MagicMock()
        secret.value = value
        secret.properties = _fake_props(name)
        return secret

    def test_metadata_only_by_default(self) -> None:
        with patch.object(secrets_mod, "get_secret_client") as mock_get:
            mock_get.return_value.get_secret.return_value = self._mock_secret()
            result = secrets_mod.get_secret("mysecret")
            assert result["name"] == "mysecret"
            assert "value" not in result

    def test_reveal_true_includes_value(self, caplog: pytest.LogCaptureFixture) -> None:
        with (
            caplog.at_level("WARNING", logger="keyvault.secrets"),
            patch.object(secrets_mod, "get_secret_client") as mock_get,
        ):
            mock_get.return_value.get_secret.return_value = self._mock_secret(value="topsecret")
            result = secrets_mod.get_secret("mysecret", reveal=True)
            assert result["value"] == "topsecret"
            assert any("revealed" in rec.message for rec in caplog.records)

    def test_invalid_name_raises_value_error(self) -> None:
        with pytest.raises(ValueError, match="Invalid secret name"):
            secrets_mod.get_secret("has spaces")

    def test_empty_name_raises_value_error(self) -> None:
        with pytest.raises(ValueError, match="Invalid secret name"):
            secrets_mod.get_secret("")

    def test_not_found_raises_key_error(self) -> None:
        with patch.object(secrets_mod, "get_secret_client") as mock_get:
            mock_get.return_value.get_secret.side_effect = Exception("SecretNotFound: mysecret")
            with pytest.raises(KeyError, match="not found"):
                secrets_mod.get_secret("mysecret")
