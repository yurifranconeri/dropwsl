# API Design

## REST Conventions

### Resource Naming

- Use **nouns**, not verbs: `/orders`, not `/getOrders`
- Use **plural** for collections: `/users`, `/products`
- Use **kebab-case** for multi-word resources: `/order-items`
- Nest for relationships: `/users/{id}/orders` (max 2 levels deep)
- Use query parameters for filtering, sorting, pagination: `/orders?status=pending&sort=-created_at`

### HTTP Methods

| Method | Semantics | Idempotent | Safe |
|---|---|---|---|
| **GET** | Read resource(s) | Yes | Yes |
| **POST** | Create resource or trigger action | No | No |
| **PUT** | Replace entire resource | Yes | No |
| **PATCH** | Partial update | No* | No |
| **DELETE** | Remove resource | Yes | No |

*PATCH can be made idempotent with JSON Merge Patch (RFC 7396).

### Status Codes

Use the correct status code — do not return 200 for everything:

| Code | When |
|---|---|
| **200 OK** | Successful GET, PUT, PATCH |
| **201 Created** | Successful POST that creates a resource — include `Location` header |
| **204 No Content** | Successful DELETE or action with no response body |
| **400 Bad Request** | Malformed request, validation error |
| **401 Unauthorized** | Missing or invalid authentication |
| **403 Forbidden** | Authenticated but not authorized |
| **404 Not Found** | Resource does not exist |
| **409 Conflict** | State conflict (duplicate, version mismatch) |
| **422 Unprocessable Entity** | Semantically invalid request (valid JSON, invalid business rules) |
| **429 Too Many Requests** | Rate limit exceeded — include `Retry-After` header |
| **500 Internal Server Error** | Unhandled server error — never expose internal details |

### Error Format (RFC 7807)

Use Problem Details for consistent error responses:

```json
{
  "type": "https://api.example.com/errors/validation",
  "title": "Validation Error",
  "status": 422,
  "detail": "The 'email' field must be a valid email address.",
  "instance": "/users/123"
}
```

- `type`: URI identifying the error type (can be a documentation link)
- `title`: human-readable summary (same for all instances of this type)
- `detail`: human-readable explanation specific to this occurrence
- `instance`: URI identifying the specific occurrence

## Pagination

### Offset-based (simple)

```
GET /orders?page=2&page_size=20
```

Response includes: `total_count`, `page`, `page_size`, `next`, `previous`.

- Simple to implement and understand
- Performance degrades with large offsets (OFFSET queries are slow)

### Cursor-based (scalable)

```
GET /orders?cursor=eyJpZCI6MTAwfQ&limit=20
```

Response includes: `next_cursor`, `has_more`.

- Consistent performance regardless of position
- Cannot jump to arbitrary pages
- Best for infinite scroll, real-time feeds

## Versioning

| Strategy | Example | Trade-offs |
|---|---|---|
| **URL path** | `/v1/users` | Simple, explicit — clutters URLs, harder to evolve |
| **Header** | `Accept: application/vnd.api+json;version=1` | Clean URLs — less discoverable |
| **Query param** | `/users?version=1` | Easy to use — pollutes query string |

- Prefer URL path versioning for simplicity — most widely adopted
- Version the API, not individual endpoints
- Breaking change = new version. Non-breaking change = same version
- Support at most 2 versions concurrently — deprecate aggressively

### Breaking vs Non-Breaking Changes

**Breaking** (requires new version):
- Removing a field or endpoint
- Changing a field type or format
- Renaming a field
- Adding a required field to request

**Non-breaking** (safe in current version):
- Adding an optional field to request or response
- Adding a new endpoint
- Adding a new optional query parameter
- Adding a new enum value (if consumers handle unknown values)

## Idempotency

- GET, PUT, DELETE are idempotent by nature
- POST is NOT idempotent — use `Idempotency-Key` header for critical operations
- Client sends a unique key; server deduplicates and returns cached response
- Store idempotency keys for at least 24 hours

## Rate Limiting

- Return `429 Too Many Requests` with `Retry-After` header
- Include rate limit headers: `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`
- Apply per-client (API key), not per-IP — IP-based limits break shared networks
- Document limits prominently in API documentation
