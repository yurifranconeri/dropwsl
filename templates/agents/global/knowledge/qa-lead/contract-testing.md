# Contract Testing

## What and Why

Contract testing verifies that two services (consumer and provider) agree on the interface between them — without deploying both at the same time.

### Problem it solves

- Integration tests require all services running → slow, flaky, expensive
- Mock-based tests can drift from reality → tests pass but production breaks
- Schema validation checks structure but not behavior → a valid schema doesn't guarantee correct semantics

### Contract = agreement on

- Request format (method, path, headers, body)
- Response format (status code, headers, body structure)
- Error responses (codes, messages, structure)
- Behavioral constraints (pagination, sorting, filtering)

## Consumer-Driven Contracts (CDC)

The consumer defines what it needs from the provider. The provider verifies it can fulfill the contract.

### Flow

1. **Consumer writes a contract**: "When I send GET /users/123, I expect status 200 and a body with `id` (number) and `name` (string)"
2. **Contract is published**: stored in a broker (Pact Broker, PactFlow) or as an artifact
3. **Provider verifies**: runs the contract against its real implementation — does it satisfy the consumer's expectations?
4. **Both sides pass → safe to deploy**: consumer and provider versions are compatible

### Benefits

- Each service tests independently — no need for integrated environment
- Consumer gets exactly what it needs — no over-fetching
- Provider knows who depends on what — safe to change unused fields
- Fast feedback — runs in seconds, not minutes

## Pact Pattern

Pact is the most widely adopted CDC framework.

### Terminology

| Term | Meaning |
|---|---|
| **Consumer** | Service that makes the request (client) |
| **Provider** | Service that handles the request (server) |
| **Interaction** | A single request-response pair |
| **Pact file** | JSON file containing all interactions for a consumer-provider pair |
| **Pact Broker** | Central repository for pact files + compatibility matrix |
| **Can I Deploy** | CLI check — are the versions of consumer and provider compatible? |

### Consumer side

1. Define interactions using Pact DSL
2. Run consumer tests — Pact creates a mock provider and records interactions
3. Pact file is generated (JSON)
4. Publish pact file to broker

### Provider side

1. Fetch pact file from broker (or local path)
2. Replay each interaction against the real provider
3. Verify responses match the contract
4. Publish verification results to broker

## Schema vs. Contract Testing

| Aspect | Schema validation | Contract testing |
|---|---|---|
| **Checks** | Structure (types, required fields) | Structure + behavior (values, status codes) |
| **Direction** | Provider defines schema | Consumer defines expectations |
| **Drift detection** | No — schema can be valid while behavior breaks | Yes — contracts are verified against real code |
| **Maintenance** | Low | Medium — contracts evolve with consumer needs |
| **When to use** | Always — as a baseline | For critical service-to-service integrations |

Use both: schema validation as a baseline, contract testing for behavioral guarantees.

## Types of Contract Testing

### Consumer-driven (CDC)

- Consumer defines the contract
- Best when: consumer team has specific requirements
- Most common approach (Pact)

### Provider-driven

- Provider publishes its API spec (OpenAPI, GraphQL schema)
- Consumers validate their usage against the spec
- Best when: provider serves many consumers with standard API

### Bi-directional

- Both sides publish: consumer publishes pact, provider publishes OpenAPI spec
- Broker compares them automatically
- Lower implementation effort — no provider verification step
- Best when: provider already has an OpenAPI spec

## When to Use Contract Testing

### Good fit

- Microservices with many inter-service API calls
- Services owned by different teams or with different release cycles
- APIs with multiple consumers (each may use different fields)
- Replacing slow, flaky end-to-end integration tests

### Not needed

- Monolith with internal function calls (use unit tests)
- Single consumer talking to a single provider (integration test suffices)
- Third-party APIs you don't control (use integration + mock tests)

## Best Practices

- Contracts test the interface, not the business logic
- Keep contracts minimal — only what the consumer actually uses
- Version pacts and tag by branch/environment
- Use `can-i-deploy` in CI before deploying any service
- Contracts are not a replacement for E2E tests — they complement each other
- Run provider verification in the provider's CI pipeline, not the consumer's
