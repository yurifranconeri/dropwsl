---
name: po-acceptance-criteria
description: "Generates structured acceptance criteria from requirements or feature descriptions"
---

# Acceptance Criteria

## When to use

When a user story, feature request, or requirement needs formal acceptance criteria.

## Process

1. Read the requirement or story
2. Identify the main behaviors and edge cases
3. Write criteria in Given/When/Then format (preferred) or checklist
4. Cover: happy path, error cases, boundary conditions, permissions
5. Verify each criterion is independently testable
6. Ask: "If all these pass, is the feature done?" â€” if not, add what's missing

## Output format

### Given/When/Then

```
AC1: <descriptive name>
  Given <precondition>
  When <action>
  Then <expected result>

AC2: <descriptive name>
  Given <precondition>
  When <action>
  Then <expected result>
```

### Checklist (for simpler stories)

```
- [ ] <observable behavior>
- [ ] <observable behavior>
- [ ] <error case handled>
```

## Quality checks

- [ ] Each AC describes observable behavior, not implementation
- [ ] No AC duplicates another
- [ ] Error cases and edge cases are covered
- [ ] Permissions and authorization scenarios are included (if applicable)
- [ ] Performance expectations are stated (if applicable)
- [ ] The set of ACs is sufficient â€” if all pass, the feature is complete
