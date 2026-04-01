---
name: tech-lead-design-doc
description: "Create a structured design document for a system or feature. Covers components, interactions, data model, API contracts, and trade-offs."
---

## When to use

- A new feature or system needs design before implementation
- A significant change to existing architecture is proposed
- Multiple teams need alignment on a technical approach
- Complexity warrants upfront analysis of trade-offs and risks

## Process

1. Understand the feature/system requirements â€” read PRD, user stories, or requirements docs
2. Identify system boundaries, actors, and key quality attributes
3. Define the high-level architecture â€” components, services, their responsibilities
4. Design data model â€” entities, relationships, storage strategy
5. Define API contracts â€” endpoints, request/response schemas, error handling
6. Map interactions â€” sequence diagrams or data flow descriptions
7. Identify cross-cutting concerns â€” security, observability, error handling, caching
8. Analyze trade-offs â€” what alternatives were considered and why this approach wins
9. List risks and open questions
10. Specify phasing if applicable â€” what ships first, what comes later

## Output format

```markdown
# Design Doc: <Feature/System Name>

## Overview

<1â€“2 paragraphs: what is being built, why, and for whom.>

## Goals and Non-Goals

### Goals
- <What this design achieves>

### Non-Goals
- <What is explicitly excluded from this scope>

## Architecture

### Components

| Component | Responsibility | Technology |
|---|---|---|
| <name> | <what it does> | <stack> |

### Interactions

<Describe how components interact. Use sequence diagrams (mermaid) or numbered flow descriptions.>

## Data Model

<Entity descriptions, relationships, key fields. ER diagram (mermaid) if helpful.>

## API Design

### <Endpoint Group>

| Method | Path | Description |
|---|---|---|
| GET | /resource | List resources |
| POST | /resource | Create a resource |

<Request/response examples for key endpoints.>

## Cross-Cutting Concerns

### Security
<Authentication, authorization, input validation, secrets management.>

### Observability
<Logging, metrics, tracing, health checks.>

### Error Handling
<Error response format, retry strategy, circuit breaker.>

### Performance
<Caching, pagination, expected latency/throughput targets.>

## Trade-offs and Alternatives

| Approach | Pros | Cons | Verdict |
|---|---|---|---|
| <chosen approach> | <pros> | <cons> | âœ… Chosen |
| <alternative> | <pros> | <cons> | âŒ Rejected |

## Risks and Open Questions

- [ ] <Risk or uncertainty that needs resolution>
- [ ] <Open question to be answered during implementation>

## Phasing

| Phase | Scope | Dependencies |
|---|---|---|
| Phase 1 (MVP) | <what ships first> | <none> |
| Phase 2 | <next increment> | <Phase 1> |

## References

- <Link to PRD, ADRs, related docs>
```

## Rules

- Goals and Non-Goals must be explicit â€” prevent scope creep
- Always include at least one alternative in Trade-offs â€” justify the chosen approach
- Data model must show key relationships â€” not just field lists
- API design follows REST conventions (see knowledge: api-design)
- Risks section must exist â€” every design has uncertainties
- Keep the doc living â€” update as decisions evolve (or create ADRs for significant changes)
