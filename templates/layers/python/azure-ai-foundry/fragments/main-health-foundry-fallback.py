    health_status = {"status": "ok"}
    # -- dropwsl:health-checks --
    health_status["azure_foundry"] = "ok" if foundry_health() else "degraded"
    return health_status
