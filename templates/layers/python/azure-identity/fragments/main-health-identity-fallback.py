    health_status = {"status": "ok"}
    # -- dropwsl:health-checks --
    auth_ok = credential_health()
    health_status["azure_identity"] = "ok" if auth_ok else "degraded"
    return health_status
