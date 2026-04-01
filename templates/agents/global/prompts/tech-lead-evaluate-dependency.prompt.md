---
name: tech-lead-evaluate-dependency
agent: tech-lead
description: "Evaluate a library or framework for adoption, replacement, or removal."
---

Evaluate the specified dependency and produce an assessment report.

## Process

1. Identify the dependency and its current usage in the project
2. Research maintenance health — releases, contributors, issue activity
3. Check license compatibility and known CVEs
4. Identify 2+ alternatives for comparison
5. Assess lock-in risk and replacement effort
6. Produce evaluation using the `dependency-analysis` skill

## Template

```
Evaluate: <library-name>

Purpose: <what it's used for or would be used for>
Context: <why evaluating — new adoption, CVE, deprecation, curiosity>
```

## Rules

- Always check CVEs — security is non-negotiable
- License must be compatible with the project
- Include at least 2 alternatives in comparison
- Assess lock-in risk even for "adopt" recommendations
