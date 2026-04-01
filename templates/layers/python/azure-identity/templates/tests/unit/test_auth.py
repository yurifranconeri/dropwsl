"""Unit tests for auth/credential.py."""

from unittest.mock import MagicMock, patch

import auth.credential as mod


class TestGetCredential:
    """Tests for get_credential() singleton."""

    def setup_method(self) -> None:
        mod._credential = None

    def test_returns_instance(self) -> None:
        with patch.object(mod, "DefaultAzureCredential") as mock_cls:
            mock_cls.return_value = MagicMock()
            cred = mod.get_credential()
            assert cred is not None
            mock_cls.assert_called_once()

    def test_singleton_returns_same_instance(self) -> None:
        with patch.object(mod, "DefaultAzureCredential") as mock_cls:
            mock_cls.return_value = MagicMock()
            cred1 = mod.get_credential()
            cred2 = mod.get_credential()
            assert cred1 is cred2
            mock_cls.assert_called_once()


class TestCredentialHealth:
    """Tests for credential_health()."""

    def setup_method(self) -> None:
        mod._credential = None

    def test_success(self) -> None:
        with patch.object(mod, "get_credential") as mock_get:
            mock_get.return_value.get_token.return_value = MagicMock()
            assert mod.credential_health() is True

    def test_failure(self) -> None:
        with patch.object(mod, "get_credential") as mock_get:
            mock_get.return_value.get_token.side_effect = Exception("no token")
            assert mod.credential_health() is False


class TestDecodeTokenClaims:
    """Tests for decode_token_claims()."""

    def test_decodes_valid_jwt(self) -> None:
        import base64
        import json

        payload = {
            "name": "Test User",
            "upn": "test@contoso.com",
            "tid": "tenant-123",
            "oid": "object-456",
            "exp": 1743264000,
        }
        encoded = base64.urlsafe_b64encode(json.dumps(payload).encode()).rstrip(b"=").decode()
        fake_jwt = f"header.{encoded}.signature"
        result = mod.decode_token_claims(fake_jwt)
        assert result["name"] == "Test User"
        assert result["upn"] == "test@contoso.com"
        assert result["tid"] == "tenant-123"
        assert result["oid"] == "object-456"
        assert "exp_iso" in result

    def test_missing_exp_no_error(self) -> None:
        import base64
        import json

        payload = {"name": "No Exp"}
        encoded = base64.urlsafe_b64encode(json.dumps(payload).encode()).rstrip(b"=").decode()
        fake_jwt = f"header.{encoded}.signature"
        result = mod.decode_token_claims(fake_jwt)
        assert result["name"] == "No Exp"
        assert "exp_iso" not in result
