    health_status = {"status": "ok"}
    # -- dropwsl:health-checks --
    postgres_ok = db_health()
    health_status["postgres"] = "ok" if postgres_ok else "degraded"
    return health_status
