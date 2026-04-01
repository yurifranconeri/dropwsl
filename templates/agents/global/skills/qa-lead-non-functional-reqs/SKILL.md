---
name: qa-lead-non-functional-reqs
description: "Defines non-functional requirements with measurable criteria and test approach"
---

# Non-Functional Requirements

## When to use

When a feature or system needs explicit non-functional requirements â€” performance, security, accessibility, reliability, or other quality attributes.

## Process

1. Identify which quality attributes are relevant for this context
2. For each attribute, define measurable criteria (SLO/SLA style)
3. Specify how each criterion will be tested and measured
4. Identify tools and environments needed for validation
5. Define acceptable thresholds and unacceptable thresholds
6. Document trade-offs between conflicting attributes

## Output format

```markdown
## Non-Functional Requirements: <feature/system>

### Performance

| Metric | Target | Unacceptable | Measurement |
|--------|--------|--------------|-------------|
| Response time (p95) | < <value>ms | > <value>ms | <tool/method> |
| Throughput | > <value> rps | < <value> rps | <tool/method> |
| Error rate under load | < <value>% | > <value>% | <tool/method> |

### Security

| Requirement | Criteria | Verification |
|-------------|----------|--------------|
| <requirement> | <measurable criteria> | <SAST/DAST/manual review> |

### Accessibility

| Requirement | Standard | Verification |
|-------------|----------|--------------|
| <requirement> | WCAG <level> | <tool/method> |

### Reliability

| Metric | Target | Measurement |
|--------|--------|-------------|
| Availability | <percentage> | Uptime monitoring |
| MTTR | < <duration> | Incident logs |
| Data durability | <criterion> | Backup/restore tests |

### Compatibility

| Dimension | Supported | Verification |
|-----------|-----------|--------------|
| <browser/OS/device/API version> | <versions> | <test approach> |

### Trade-offs

- <attribute A> vs <attribute B>: <decision and rationale>
```

## Rules

- Every NFR must be measurable â€” "fast" is not a requirement, "p95 < 200ms" is
- Define both the target (acceptable) and the unacceptable threshold
- Specify how each NFR will be verified â€” untestable requirements are useless
- Document trade-offs explicitly â€” you cannot optimize everything simultaneously
- Only include relevant attributes â€” not every system needs every NFR category
