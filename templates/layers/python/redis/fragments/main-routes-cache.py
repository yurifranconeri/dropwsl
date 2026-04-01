


# --- Cache (Redis) -- example routes ---


@app.put("/cache/{key}")
async def cache_set(
    key: str,
    value: str,
    ttl: int | None = None,
    r: aioredis.Redis = Depends(get_redis),
) -> dict[str, str]:
    """Writes a value to cache. Optional TTL in seconds."""
    await r.set(key, value, ex=ttl)
    return {"key": key, "value": value}


@app.get("/cache/{key}")
async def cache_get(
    key: str, r: aioredis.Redis = Depends(get_redis),
) -> dict[str, str | None]:
    """Reads a value from cache. Returns null if not found."""
    value = await r.get(key)
    return {"key": key, "value": value}


@app.delete("/cache/{key}", status_code=204)
async def cache_delete(
    key: str, r: aioredis.Redis = Depends(get_redis),
) -> None:
    """Removes a key from cache."""
    await r.delete(key)
