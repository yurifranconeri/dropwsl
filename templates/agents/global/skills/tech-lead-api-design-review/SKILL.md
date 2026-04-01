---
name: tech-lead-api-design-review
description: "Design or review an API. Covers resource model, endpoints, error format, versioning, pagination, and adherence to REST conventions."
---

## When to use

- Designing a new API before implementation
- Reviewing an existing API for consistency and best practices
- Evaluating a third-party API integration
- Planning a breaking change or version migration
- Standardizing API patterns across services

## Process

1. Understand the domain â€” read requirements, existing docs, entity relationships
2. Identify resources (nouns) and their relationships
3. Define endpoints â€” CRUD operations, custom actions, nested resources
4. Design request/response schemas for key operations
5. Define error handling strategy â€” RFC 7807 format, error codes
6. Choose pagination strategy â€” offset-based or cursor-based
7. Define authentication and authorization model
8. Plan versioning strategy â€” when and how to version
9. Review for REST convention compliance
10. Document as OpenAPI specification or structured API design doc

## Output format

```markdown
# API Design: <API Name>

## Overview

<Brief description: what this API does, who the consumers are, key use cases.>

## Base URL

```
https://api.example.com/v1
```

## Authentication

<Auth mechanism: OAuth 2.0, API key, JWT. Include required headers/scopes.>

## Resources

### <Resource Name>

<Description of the resource. Relationship to other resources.>

#### Endpoints

| Method | Path | Description | Auth |
|---|---|---|---|
| GET | /<resources> | List all (paginated) | Required |
| GET | /<resources>/{id} | Get by ID | Required |
| POST | /<resources> | Create new | Required |
| PUT | /<resources>/{id} | Replace | Required |
| DELETE | /<resources>/{id} | Delete | Required |

#### Schema

```json
{
  "id": "uuid",
  "field_1": "string",
  "field_2": 0,
  "created_at": "2024-01-01T00:00:00Z",
  "updated_at": "2024-01-01T00:00:00Z"
}
```

#### Query Parameters

| Parameter | Type | Description | Default |
|---|---|---|---|
| page | int | Page number | 1 |
| page_size | int | Items per page (max 100) | 20 |
| sort | string | Sort field (prefix - for desc) | -created_at |
| filter | string | Filter expression | â€” |

## Error Format

All errors follow RFC 7807 Problem Details:

```json
{
  "type": "https://api.example.com/errors/<error-type>",
  "title": "Human-readable title",
  "status": 422,
  "detail": "Specific error description",
  "instance": "/resource/123"
}
```

### Error Codes

| Status | Type | When |
|---|---|---|
| 400 | /errors/bad-request | Malformed request body |
| 401 | /errors/unauthorized | Missing/invalid auth |
| 403 | /errors/forbidden | Insufficient permissions |
| 404 | /errors/not-found | Resource doesn't exist |
| 409 | /errors/conflict | State conflict |
| 422 | /errors/validation | Business rule violation |
| 429 | /errors/rate-limited | Rate limit exceeded |

## Pagination

<Chosen strategy: offset or cursor. Response format.>

## Versioning

<Strategy: URL path /v1/. Breaking change policy.>

## Rate Limiting

<Limits per client. Headers: X-RateLimit-Limit, Remaining, Reset.>

## Review Findings (if reviewing existing API)

| # | Finding | Severity | Recommendation |
|---|---|---|---|
| 1 | <issue found> | High/Medium/Low | <fix> |
```

## Rules

- Resources are nouns, not verbs â€” `/orders`, not `/createOrder`
- Use plural for collections â€” `/users`, not `/user`
- Nest max 2 levels â€” `/users/{id}/orders`, not `/users/{id}/orders/{oid}/items/{iid}`
- Every endpoint must have documented request/response examples
- Error responses must follow RFC 7807 â€” no custom error formats
- Include pagination from day one â€” even if there are few records today
- Document breaking vs non-breaking change policy
