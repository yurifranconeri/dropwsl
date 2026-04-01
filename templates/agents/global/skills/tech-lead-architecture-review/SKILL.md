---
name: tech-lead-architecture-review
description: "Review existing architecture. Produces a report with findings, risks, quality attribute assessment (ISO 25010), and actionable recommendations."
---

## When to use

- Periodic architecture health check
- Before a major refactoring or modernization effort
- After significant growth in team size, traffic, or feature scope
- When development velocity is decreasing without obvious cause
- When onboarding new Tech Lead to an existing project

## Process

1. Read project documentation â€” README, ADRs, existing design docs, architecture diagrams
2. Explore codebase structure â€” directories, modules, dependency graph, layer boundaries
3. Identify architectural patterns in use â€” layered, hexagonal, modular monolith, etc.
4. Assess each quality attribute (ISO 25010) against current state
5. Identify coupling issues â€” circular dependencies, shared mutable state, hidden dependencies
6. Review API design â€” consistency, versioning, error handling
7. Check observability posture â€” logging, metrics, tracing, health checks
8. Review dependency health â€” outdated libraries, known CVEs, maintenance status
9. Categorize findings by severity (Critical, High, Medium, Low)
10. Write actionable recommendations with expected impact

## Output format

```markdown
# Architecture Review: <Project Name>

## Executive Summary

<2â€“3 sentences: overall health, biggest risks, key recommendations.>

## Current Architecture

<Brief description of the architecture: style, major components, data stores, integrations.>

## Quality Attribute Assessment

| Attribute | Rating | Findings |
|---|---|---|
| Maintainability | ðŸŸ¢ðŸŸ¡ðŸ”´ | <key findings> |
| Reliability | ðŸŸ¢ðŸŸ¡ðŸ”´ | <key findings> |
| Performance | ðŸŸ¢ðŸŸ¡ðŸ”´ | <key findings> |
| Security | ðŸŸ¢ðŸŸ¡ðŸ”´ | <key findings> |
| Scalability | ðŸŸ¢ðŸŸ¡ðŸ”´ | <key findings> |
| Testability | ðŸŸ¢ðŸŸ¡ðŸ”´ | <key findings> |

## Findings

### Critical

- **<Finding title>**: <description, evidence, impact>

### High

- **<Finding title>**: <description, evidence, impact>

### Medium

- **<Finding title>**: <description, evidence, impact>

### Low

- **<Finding title>**: <description, evidence, impact>

## Technical Debt Summary

| Category | Items | Interest Level |
|---|---|---|
| Code debt | <count> | High/Medium/Low |
| Design debt | <count> | High/Medium/Low |
| Architecture debt | <count> | High/Medium/Low |
| Test debt | <count> | High/Medium/Low |
| Dependency debt | <count> | High/Medium/Low |

## Recommendations

| # | Recommendation | Severity | Effort | Impact |
|---|---|---|---|---|
| 1 | <actionable recommendation> | Critical/High/Medium | S/M/L | <expected improvement> |
| 2 | <actionable recommendation> | High | S/M/L | <expected improvement> |

## Risks

- <Risk that needs monitoring or mitigation>

## References

- <Links to ADRs, docs, tools used for analysis>
```

## Rules

- Findings must include evidence â€” "module X has cyclomatic complexity of 45" not "code is complex"
- Every finding must have a recommendation â€” observations without actions are not useful
- Rate quality attributes honestly â€” green/yellow/red with evidence
- Sort recommendations by impact â€” highest impact first
- Keep executive summary to 3 sentences max â€” busy stakeholders read only this
- This is an assessment, not a rewrite proposal â€” recommend incremental improvements
