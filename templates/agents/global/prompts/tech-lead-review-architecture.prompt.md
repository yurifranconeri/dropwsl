---
name: tech-lead-review-architecture
agent: tech-lead
description: "Analyze the current architecture and produce a review report with findings and recommendations."
---

Review the project's architecture and produce a structured assessment.

## Process

1. Read README, docs, ADRs, and existing architecture documentation
2. Explore the codebase structure — modules, layers, dependencies
3. Assess quality attributes (ISO 25010): maintainability, reliability, performance, security, scalability, testability
4. Identify architectural risks, coupling issues, and debt hotspots
5. Produce an architecture review using the `architecture-review` skill

## Template

```
Review the architecture of this project.

Focus areas: <optional — e.g., "scalability", "security", "maintainability">
Context: <optional — recent changes, growth, or concerns>
```

## Rules

- Findings must include evidence from the codebase
- Every finding must have an actionable recommendation
- Rate quality attributes with 🟢🟡🔴 and justify
