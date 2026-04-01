---
name: qa-lead-plan-regression
agent: qa-lead
description: "Analyzes a change and recommends the regression testing scope"
---

# Plan Regression

Determine the right regression scope for a code change, dependency update, or release.

## Process

1. Ask for: what changed, why, and what areas might be affected
2. Identify changed files and trace dependencies
3. Classify change type (bug fix, feature, refactoring, dependency, config)
4. Map affected areas to existing test suites
5. Assess risk per affected area
6. Recommend scope: smoke, shallow regression, or full regression
7. List must-run tests and coverage gaps

## Template

```markdown
# Regression Plan: <change description>

## Change Classification

- **Type**: <bug fix / feature / refactoring / dependency / config>
- **Changed**: <files/modules>
- **Blast radius**: <affected downstream components>

## Impact Analysis

| Area | Risk | Coverage | Action |
|------|------|----------|--------|
| <area> | High/Med/Low | Good/Partial/None | Must test / Should test / Skip |

## Recommended Scope

**Level**: Smoke / Shallow / Full

**Rationale**: <why this level is appropriate>

## Must-Run Tests

- <test/suite> — <reason>

## Coverage Gaps

- <area without tests> — <recommendation>
```

## Rules

- Trace dependencies in both directions — upstream consumers and downstream dependencies
- When in doubt, choose the broader scope — under-testing is riskier than over-testing
- Coverage gaps must be documented — silence about gaps is a risk
