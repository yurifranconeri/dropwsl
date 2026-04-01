# Architecture Decision Records (ADRs)

## What is an ADR

An Architecture Decision Record captures a significant technical decision along with its context,
constraints, options considered, and consequences. ADRs create a decision log that explains
WHY the system looks the way it does — not just WHAT was built.

## When to write an ADR

- Choosing a technology, framework, or library
- Defining a structural pattern (layered, hexagonal, microservices)
- Changing an integration approach (sync vs async, REST vs gRPC)
- Establishing a data strategy (SQL vs NoSQL, caching, replication)
- Making a security architecture choice (auth mechanism, encryption)
- Deciding a deployment strategy (containers, serverless, PaaS)
- Any decision that is hard to reverse or affects multiple teams

## MADR Format

Use the Markdown Any Decision Record (MADR) template:

```markdown
# ADR-NNNN: <Title>

## Status

Proposed | Accepted | Deprecated | Superseded by ADR-XXXX

## Context

<What is the issue? What forces are at play? What constraints exist?>

## Decision Drivers

- <driver 1>
- <driver 2>

## Considered Options

1. <Option A>
2. <Option B>
3. <Option C>

## Decision Outcome

Chosen option: "<Option X>", because <justification>.

### Consequences

#### Good
- <positive consequence>

#### Bad
- <negative consequence or trade-off>

#### Neutral
- <side effect that is neither good nor bad>
```

## ADR Lifecycle

| Status | Meaning |
|---|---|
| **Proposed** | Under discussion — not yet accepted |
| **Accepted** | Decision made — applies going forward |
| **Deprecated** | No longer relevant — context changed |
| **Superseded** | Replaced by a newer ADR (link to successor) |

- Accepted ADRs are immutable — do NOT edit the decision after acceptance
- If the decision needs to change, create a new ADR that supersedes the old one
- Deprecated/Superseded ADRs remain in the log — they are part of the decision history

## Decision Categories

| Category | Examples |
|---|---|
| **Technology** | Language, framework, database, message broker, cloud service |
| **Pattern** | Architecture style, design pattern, integration pattern |
| **Integration** | API protocol, sync vs async, event schema format |
| **Data** | Schema strategy, migration approach, caching layer, consistency model |
| **Security** | Authentication mechanism, authorization model, encryption, secrets management |
| **Deployment** | Container strategy, CI/CD pipeline, environment topology, scaling policy |
| **Process** | Branching strategy, code review policy, release cadence |

## Principles

- **Context over decision**: a well-documented context makes the decision self-evident
- **Trade-offs over absolutes**: every option has pros and cons — document both
- **Reversibility matters**: distinguish one-way doors (hard to reverse) from two-way doors (easy to change)
- **Scope appropriately**: one ADR per decision — avoid bundling multiple choices
- **Number sequentially**: `ADR-0001`, `ADR-0002`, etc. — never reuse numbers
- **Link related ADRs**: reference predecessor/successor decisions
