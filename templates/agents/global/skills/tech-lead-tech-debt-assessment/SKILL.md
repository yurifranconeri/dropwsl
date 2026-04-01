---
name: tech-lead-tech-debt-assessment
description: "Assess technical debt in the codebase. Produces a categorized inventory with Fowler quadrant classification, interest estimation, and remediation plan."
---

## When to use

- Sprint planning needs debt allocation decisions
- Development velocity is declining
- Team reports increasing friction in specific areas
- Before a major feature that will touch debt-heavy modules
- Quarterly or periodic debt review

## Process

1. Read project docs, README, and recent PRs/commits for context
2. Explore codebase structure â€” identify hotspots (frequently changed, complex files)
3. Check for code smells â€” long functions, deep nesting, duplicated code, poor naming
4. Analyze design â€” coupling between modules, missing abstractions, circular dependencies
5. Review test coverage â€” gaps, flaky tests, missing integration tests
6. Check dependencies â€” outdated versions, known CVEs, deprecated APIs
7. Review infrastructure â€” manual processes, missing automation, observability gaps
8. Classify each debt item by category and Fowler quadrant
9. Estimate interest â€” impact on velocity, bug frequency, onboarding time
10. Prioritize remediation â€” high-interest debt first

## Output format

```markdown
# Tech Debt Assessment: <Project Name>

## Summary

| Category | Items | High Interest | Medium Interest | Low Interest |
|---|---|---|---|---|
| Code | <n> | <n> | <n> | <n> |
| Design | <n> | <n> | <n> | <n> |
| Architecture | <n> | <n> | <n> | <n> |
| Test | <n> | <n> | <n> | <n> |
| Infrastructure | <n> | <n> | <n> | <n> |
| Dependency | <n> | <n> | <n> | <n> |
| **Total** | **<n>** | **<n>** | **<n>** | **<n>** |

## Debt Inventory

### Code Debt

| # | Item | Location | Quadrant | Interest | Remediation |
|---|---|---|---|---|---|
| 1 | <description> | <file/module> | Prudent/Deliberate | High | <fix approach> |

### Design Debt

| # | Item | Location | Quadrant | Interest | Remediation |
|---|---|---|---|---|---|
| 1 | <description> | <module/area> | <quadrant> | <level> | <fix approach> |

### Architecture Debt

| # | Item | Location | Quadrant | Interest | Remediation |
|---|---|---|---|---|---|
| 1 | <description> | <area> | <quadrant> | <level> | <fix approach> |

### Test Debt

| # | Item | Location | Quadrant | Interest | Remediation |
|---|---|---|---|---|---|
| 1 | <description> | <area> | <quadrant> | <level> | <fix approach> |

### Infrastructure Debt

| # | Item | Location | Quadrant | Interest | Remediation |
|---|---|---|---|---|---|
| 1 | <description> | <area> | <quadrant> | <level> | <fix approach> |

### Dependency Debt

| # | Item | Current | Latest | CVEs | Remediation |
|---|---|---|---|---|---|
| 1 | <library> | <version> | <version> | <count> | <upgrade path> |

## Remediation Plan

### Immediate (this sprint)

- [ ] <High-interest item with clear fix>

### Short-term (next 2â€“4 sprints)

- [ ] <Items that are slowing current work>

### Medium-term (next quarter)

- [ ] <Strategic debt that needs planning>

## Recommendations

- <Sprint allocation suggestion â€” e.g., "Reserve 20% of capacity for debt reduction">
- <Process improvements to prevent new debt accumulation>

## References

- <Tools used, analysis outputs, related ADRs>
```

## Rules

- Every debt item must have a location â€” "somewhere in the codebase" is not useful
- Classify using Fowler quadrant â€” it clarifies whether the debt was deliberate or accidental
- Interest level drives priority â€” fix high-interest debt first regardless of principal
- Remediation must be actionable â€” "refactor this" is too vague, specify the approach
- Include dependency CVEs when applicable â€” security debt cannot be deferred indefinitely
- Assessment is a snapshot â€” record the date and plan for periodic updates
