    health_status = {"status": "ok"}
    # -- dropwsl:health-checks --
    redis_ok = await redis_health()
    health_status["redis"] = "ok" if redis_ok else "degraded"
    return health_status
