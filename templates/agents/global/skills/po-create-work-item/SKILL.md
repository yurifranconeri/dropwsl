---
name: po-create-work-item
description: "Creates a user story with acceptance criteria and registers it as a GitHub issue"
---

# Create Work Item

## When to use

When a requirement, feature request, or bug needs to be tracked as a formal work item.

## Process

1. Ask for: user role, goal, benefit, and any known constraints
2. Write the user story in "As a / I want / So that" format
3. Generate acceptance criteria (Given/When/Then or checklist)
4. Assign labels: `type` (feature, bug, chore), `priority` (must, should, could)
5. Create a GitHub issue with the story, ACs, and labels
6. If the story is too large (multiple sprint efforts), suggest splitting

## Output format

### GitHub Issue

**Title**: `<type>: <short description>`

**Body**:
```markdown
## User Story

As a <role>,
I want <goal>,
so that <benefit>.

## Acceptance Criteria

- [ ] Given <precondition>, when <action>, then <result>
- [ ] ...

## Notes

<context, constraints, dependencies>
```

**Labels**: `type/<type>`, `priority/<level>`

## Rules

- One story per issue â€” never bundle multiple stories
- The story describes WHAT and WHY, never HOW
- Every AC must be testable
- If implementation details are needed, add them under Notes â€” not in the story
