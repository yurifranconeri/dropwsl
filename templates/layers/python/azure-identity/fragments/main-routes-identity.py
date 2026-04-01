


# --- Identity (Azure) -- credential info ---


@app.get("/api/identity")
def identity_info() -> dict:
    """Return decoded JWT claims from the current Azure credential."""
    try:
        credential = get_credential()
        token = credential.get_token("https://management.azure.com/.default")
        claims = decode_token_claims(token.token)
        return {
            "authenticated": True,
            "name": claims.get("name", ""),
            "email": claims.get("upn", claims.get("unique_name", "")),
            "tenant_id": claims.get("tid", ""),
            "object_id": claims.get("oid", ""),
            "token_expires_at": claims.get("exp_iso", ""),
        }
    except Exception as exc:
        return {
            "authenticated": False,
            "error": f"DefaultAzureCredential failed: {exc}. Run 'az login' to authenticate.",
        }
