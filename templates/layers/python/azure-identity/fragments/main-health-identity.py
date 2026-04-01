    auth_ok = credential_health()
    health_status["azure_identity"] = "ok" if auth_ok else "degraded"
