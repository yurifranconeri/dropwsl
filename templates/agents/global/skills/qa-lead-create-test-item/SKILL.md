---
name: qa-lead-create-test-item
description: "Creates a test-related work item (test task, bug report, or test debt) as a GitHub issue"
---

# Create Test Item

## When to use

When a test task, bug, test improvement, or quality debt needs to be tracked as a formal work item.

## Process

1. Classify the item type: test task, bug report, test debt, or test improvement
2. Write a clear title with the type prefix
3. Describe the item with context, steps, and expected outcome
4. For bugs: include reproduction steps, actual vs expected, severity, environment
5. Assign labels: `type` and `priority`
6. Create a GitHub issue

## Output format

### Bug Report

```markdown
**Title**: `bug: <short description>`

## Summary

<One-line description of the defect>

## Reproduction Steps

1. <step>
2. <step>
3. <step>

## Expected Behavior

<What should happen>

## Actual Behavior

<What actually happens>

## Environment

- <OS, browser, API version, etc.>

## Severity

- **Severity**: Critical / High / Medium / Low
- **Impact**: <business impact description>

## Evidence

<Screenshots, logs, error messages>
```

**Labels**: `type/bug`, `priority/<level>`, `area/<component>`

### Test Task

```markdown
**Title**: `test: <short description>`

## Objective

<What this test task aims to validate>

## Scope

- <areas/features to test>

## Approach

- <test levels and techniques to apply>

## Acceptance Criteria

- [ ] <measurable completion condition>
```

**Labels**: `type/test`, `priority/<level>`

### Test Debt

```markdown
**Title**: `test-debt: <short description>`

## Current State

<What coverage or quality is missing>

## Desired State

<What should be in place>

## Justification

<Risk of not addressing this debt>

## Effort Estimate

- **Size**: S / M / L
```

**Labels**: `type/test-debt`, `priority/<level>`

## Rules

- One item per issue â€” never bundle multiple items
- Bugs must always have reproduction steps â€” "it doesn't work" is not a bug report
- Severity reflects business impact, not technical complexity
- Test debt must include justification â€” why this gap matters
