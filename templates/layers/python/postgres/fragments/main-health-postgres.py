    postgres_ok = db_health()
    health_status["postgres"] = "ok" if postgres_ok else "degraded"
