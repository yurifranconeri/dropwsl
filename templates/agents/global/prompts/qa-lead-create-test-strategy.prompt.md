---
name: qa-lead-create-test-strategy
agent: qa-lead
description: "Creates a comprehensive test strategy for a project or major feature"
---

# Create Test Strategy

Define the overall testing approach for a project, epic, or major feature.

## Process

1. Ask for: what is being built, who are the users, what are the quality goals
2. Identify the system architecture (monolith, microservices, frontend, API)
3. Assess risk areas — where are bugs most likely and most damaging?
4. Define test levels and their proportions (pyramid, honeycomb, or trophy)
5. Define test types needed (functional, performance, security, accessibility)
6. Specify automation strategy — what to automate, what to keep manual
7. Define CI/CD integration points
8. Document tool recommendations and environment needs

## Template

```markdown
# Test Strategy: <project/feature>

## Quality Goals

- <measurable quality objective>

## Architecture Overview

<System shape and key components relevant to testing>

## Risk Assessment

| Area | Risk Level | Rationale |
|------|-----------|-----------|
| <area> | Critical/High/Med/Low | <why> |

## Test Levels

- **Unit**: <scope and approach>
- **Integration**: <scope and approach>
- **Contract**: <scope and approach, if applicable>
- **E2E**: <scope and approach>

## Test Types

- **Performance**: <approach or N/A>
- **Security**: <approach or N/A>
- **Accessibility**: <approach or N/A>

## Automation Strategy

- **Automate**: <what and why>
- **Manual**: <what and why>

## CI/CD Integration

- **PR build**: <what runs>
- **Main branch**: <what runs>
- **Pre-deploy**: <what runs>

## Tools

| Purpose | Tool |
|---------|------|
| <purpose> | <tool> |
```

## Rules

- Strategy must align with the system architecture — microservices need contracts, monoliths need more integration
- Every recommendation must have a rationale — "because it's best practice" is not enough
- Be specific about what NOT to test — unbounded strategies are useless
