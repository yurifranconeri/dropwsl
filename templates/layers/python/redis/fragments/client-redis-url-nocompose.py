REDIS_URL = os.getenv("REDIS_URL")
if not REDIS_URL:
    raise RuntimeError(
        "REDIS_URL not configured. "
        "Set it in .env (e.g.: REDIS_URL=redis://host:6379/0)"
    )
