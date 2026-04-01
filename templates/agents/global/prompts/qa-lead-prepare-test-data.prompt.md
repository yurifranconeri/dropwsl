---
name: qa-lead-prepare-test-data
agent: qa-lead
description: "Plans test data for a feature or test suite"
---

# Prepare Test Data

Define the test data needed for a feature, test suite, or test scenario.

## Process

1. Ask for: what feature is being tested, what entities are involved
2. Identify all data entities and their relationships
3. For each entity, define fields, constraints, and volumes
4. Identify sensitive fields requiring masking
5. Plan boundary and error data
6. Define the data lifecycle (creation, cleanup)

## Template

```markdown
# Test Data Plan: <feature>

## Entities

### <Entity name>
- **Source**: Factory / Fixture / Synthetic / Snapshot
- **Volume**: <count>
- **Key fields**:
  | Field | Type | Constraints | Sensitive |
  |-------|------|-------------|-----------|
  | <field> | <type> | <rules> | Yes/No |
- **Relationships**: <dependencies>

## Boundary Data

| Field | Min | Max | Edge cases |
|-------|-----|-----|------------|
| <field> | <value> | <value> | <list> |

## Error Scenarios

- <malformed input description>
- <constraint violation description>

## Cleanup

<transaction rollback / teardown script / ephemeral container>
```

## Rules

- Never use real PII — always generate synthetic or mask production data
- Include boundary and error data explicitly
- Each test must be independent — no shared mutable state
