---
name: dev-new-endpoint
agent: developer
description: "Scaffolds a new API endpoint with route, model, and test"
---

# New Endpoint

Create a new API endpoint following project conventions.

## Process

1. Ask for: HTTP method, path, request/response schema, business logic
2. Create Pydantic models for request and response in the appropriate module
3. Create the route handler using `@app.method` or `@router.method`
4. Use dependency injection for shared concerns (auth, db)
5. Return the response model with the correct status code
6. Create test in `tests/` using `TestClient`
7. Run `ruff check .` and `pytest`

## Template

```python
@router.post("/<path>", response_model=<ResponseModel>, status_code=status.HTTP_201_CREATED)
async def create_<resource>(<params>, <deps>) -> <ResponseModel>:
    """<Description>."""
    # business logic
    return <ResponseModel>(...)
```
