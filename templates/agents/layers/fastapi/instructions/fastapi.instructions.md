---
applyTo: "**/*.py"
---

# FastAPI Rules

- Use dependency injection (`Depends()`) for shared logic (auth, database sessions, config)
- Use Pydantic `BaseModel` for all request and response schemas — never raw dicts
- Define response models explicitly: `@app.get("/items", response_model=list[Item])`
- Use `HTTPException` with specific status codes — never return raw error strings
- Use lifespan events for startup/shutdown logic (database connections, caches)
- Use `BackgroundTasks` for fire-and-forget work — not for critical operations
- Use path operation decorators with explicit methods: `@app.get`, `@app.post` — not `@app.api_route`
- Keep route handlers thin — delegate business logic to service functions
- Group related routes with `APIRouter` and include with prefix
- Use `status` module for HTTP codes: `status.HTTP_201_CREATED`
