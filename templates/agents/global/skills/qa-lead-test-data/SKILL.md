---
name: qa-lead-test-data
description: "Plans test data generation, fixtures, and anonymization for a test scenario"
---

# Test Data

## When to use

When test scenarios need specific data â€” fixtures, factories, synthetic data, or anonymized production snapshots.

## Process

1. Read the test cases and identify all data requirements
2. Classify each data need: static fixture, dynamic factory, or production snapshot
3. For each data set, define: fields, constraints, volume, relationships
4. Identify sensitive fields that require masking or anonymization
5. Define the data lifecycle: creation, usage, cleanup
6. Specify environment-specific considerations (local vs CI vs staging)

## Output format

```markdown
## Test Data Plan: <feature/test suite>

### Data Sets

#### DS-01: <entity name>
- **Type**: Fixture / Factory / Synthetic / Snapshot
- **Volume**: <number of records>
- **Fields**:
  | Field | Type | Constraints | Sensitive | Masking |
  |-------|------|-------------|-----------|---------|
  | <field> | <type> | <rules> | Yes/No | <technique> |
- **Relationships**: <foreign keys, dependencies>
- **Lifecycle**: <created before suite / per test / shared>

### Boundary Data

- <field>: min=<value>, max=<value>, edge cases: <list>

### Error Data

- <scenario>: <malformed/invalid data description>

### Cleanup Strategy

- <approach: transaction rollback / teardown / ephemeral container>
```

## Rules

- Never use real PII in test data â€” always mask or generate synthetic
- Each test should be independent â€” no shared mutable data between tests
- Document the masking technique for every sensitive field
- Include boundary and error data explicitly â€” do not leave it to chance
