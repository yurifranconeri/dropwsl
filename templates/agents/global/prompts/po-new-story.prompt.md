---
name: po-new-story
agent: po
description: "Interactive user story creation with acceptance criteria"
---

# New Story

Create a user story following INVEST principles.

## Process

1. Ask for: who is the user, what do they want to accomplish, and why
2. Write the story in "As a / I want / So that" format
3. Generate acceptance criteria (Given/When/Then)
4. Suggest labels: type (feature, bug, chore) and priority (must, should, could)
5. Ask if the story should be created as a GitHub issue
6. If the story is too large, suggest how to split it

## Template

```markdown
## User Story

As a <role>,
I want <goal>,
so that <benefit>.

## Acceptance Criteria

- [ ] Given <precondition>, when <action>, then <result>
- [ ] Given <precondition>, when <action>, then <result>

## Notes

<constraints, dependencies, context>
```
