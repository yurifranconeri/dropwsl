---
name: tech-lead-assess-tech-debt
agent: tech-lead
description: "Scan the codebase for technical debt and produce a categorized assessment with remediation plan."
---

Assess technical debt in the project and produce an actionable report.

## Process

1. Read project docs for context — README, ADRs, recent issues
2. Explore the codebase — identify complex modules, duplicated code, poor abstractions
3. Check test coverage and test quality
4. Review dependency versions and known CVEs
5. Classify debt using Fowler quadrant and interest levels
6. Produce assessment using the `tech-debt-assessment` skill

## Template

```
Assess the technical debt in this project.

Focus: <optional — e.g., "dependency debt", "test debt", "specific module">
Context: <optional — velocity concerns, upcoming changes>
```

## Rules

- Every debt item must reference a specific location in the codebase
- Prioritize by interest (impact on velocity), not size
- Remediation plan must have immediate, short-term, and medium-term phases
