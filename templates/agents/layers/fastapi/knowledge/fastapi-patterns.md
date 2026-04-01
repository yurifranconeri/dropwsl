# FastAPI Patterns

## Route organization

- Group routes by domain with `APIRouter`
- Each router in its own module: `routers/users.py`, `routers/items.py`
- Include routers with prefix: `app.include_router(users_router, prefix="/users")`
- Keep route handlers under 10-15 lines — delegate to services

## Dependency injection

- Use `Depends()` for cross-cutting concerns: auth, db session, config, pagination
- Dependencies can depend on other dependencies — compose them
- Use `yield` dependencies for resources that need cleanup (db sessions)
- Scope: each request gets its own dependency instance by default

## Request/response models

- Separate models for create, update, and response: `UserCreate`, `UserUpdate`, `UserResponse`
- Use `Field()` for validation: `Field(min_length=1, max_length=100)`
- Use `model_config = ConfigDict(from_attributes=True)` for ORM compatibility
- Return Pydantic models, not dicts — FastAPI handles serialization

## Error handling

- Raise `HTTPException` for client errors (4xx)
- Use custom exception handlers for domain exceptions
- Return consistent error shape: `{"detail": "message"}`
- Never expose internal errors to clients — log them, return generic 500

## Async

- Use `async def` for route handlers that do I/O (database, HTTP calls)
- Use `def` (sync) for CPU-bound handlers — FastAPI runs them in threadpool
- Never call blocking I/O inside `async def` — use `asyncio.to_thread()`
- Use `httpx.AsyncClient` for outbound HTTP calls (not `requests`)

## Testing

- Use `TestClient` (sync) or `httpx.AsyncClient` (async) from `httpx`
- Test routes through the HTTP interface, not by calling functions directly
- Override dependencies in tests: `app.dependency_overrides[get_db] = mock_db`
- Test response status codes, body, and headers
- Test error cases: invalid input, missing auth, not found

## Security

- Use `OAuth2PasswordBearer` or custom auth dependency
- Validate tokens in a dependency — not in route handlers
- Use CORS middleware with explicit allowed origins (not `*` in production)
- Rate limiting: use middleware or reverse proxy
- Never trust client-supplied IDs for authorization — always verify ownership
