---
name: qa-lead-regression-analysis
description: "Analyzes change impact and recommends regression test scope"
---

# Regression Analysis

## When to use

When a code change, dependency update, or configuration change needs impact analysis to determine which regression tests to run.

## Process

1. Identify what changed â€” files, modules, functions, configs, dependencies
2. Trace the blast radius â€” what depends on the changed code?
3. Classify the change type: bug fix, new feature, refactoring, dependency update, config
4. Map affected areas to existing test suites
5. Assess risk for each affected area (business impact Ã— change probability)
6. Recommend regression scope: smoke, shallow, or full
7. Identify any coverage gaps â€” areas affected but lacking tests

## Output format

```markdown
## Regression Analysis: <change description>

### Change Summary

- **Type**: Bug fix / Feature / Refactoring / Dependency update / Config
- **Changed**: <files/modules list>
- **Blast radius**: <affected components>

### Impact Map

| Affected area | Risk level | Existing coverage | Recommendation |
|---------------|-----------|-------------------|----------------|
| <area> | Critical/High/Med/Low | Good/Partial/None | Must test / Should test / Monitor |

### Recommended Scope

- **Level**: Smoke / Shallow regression / Full regression
- **Justification**: <why this level>

### Must-Run Tests

- <test suite or test case> â€” <reason>
- <test suite or test case> â€” <reason>

### Coverage Gaps

- <area with no tests> â€” <recommendation to add coverage>

### Risk Acceptance

- <known risk not covered by tests> â€” <mitigation or acceptance rationale>
```

## Rules

- Always trace dependencies in both directions â€” upstream and downstream
- Coverage gaps must be documented explicitly â€” not silently ignored
- The recommended scope must match the risk level â€” never under-test critical changes
- If in doubt, recommend the broader scope â€” safety over speed
