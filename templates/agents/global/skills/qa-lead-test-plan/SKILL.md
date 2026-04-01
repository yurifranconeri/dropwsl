---
name: qa-lead-test-plan
description: "Creates a structured test plan for a feature, sprint, or release"
---

# Test Plan

## When to use

When a new feature, sprint, or release needs a test plan defining scope, approach, resources, and schedule.

## Process

1. Read the requirements, user stories, and acceptance criteria
2. Identify the scope â€” what will be tested and what will NOT
3. Assess risk â€” use the risk matrix to prioritize testing effort
4. Define test levels: unit, integration, contract, E2E
5. Define test types: functional, performance, security, accessibility (as applicable)
6. Specify entry and exit criteria
7. Identify test data needs and environment requirements
8. Define the regression strategy for this change
9. Document assumptions, dependencies, and risks

## Output format

```markdown
# Test Plan: <feature/sprint/release name>

## Scope

### In scope
- <feature/module/area>
- <feature/module/area>

### Out of scope
- <feature/module/area> â€” reason

## Risk Assessment

| Area | Impact | Probability | Priority | Mitigation |
|------|--------|-------------|----------|------------|
| <area> | High/Med/Low | High/Med/Low | <result> | <approach> |

## Test Approach

### Test levels
- **Unit**: <what will be unit tested>
- **Integration**: <what will be integration tested>
- **Contract**: <consumer-provider pairs, if applicable>
- **E2E**: <critical journeys>

### Test types
- **Functional**: <approach>
- **Performance**: <approach, if applicable>
- **Security**: <approach, if applicable>
- **Accessibility**: <approach, if applicable>

## Test Data

- <data needs and preparation approach>

## Environment

- <environment requirements>

## Entry Criteria

- [ ] <precondition>

## Exit Criteria

- [ ] <completion condition>

## Risks and Assumptions

- <assumption or risk>
```

## Rules

- Every test plan must have explicit scope boundaries â€” "out of scope" is as important as "in scope"
- Risk assessment drives effort allocation â€” high-risk areas get more coverage
- Entry and exit criteria must be measurable and verifiable
- Do not plan tests you cannot execute â€” match plan to available tools and time
