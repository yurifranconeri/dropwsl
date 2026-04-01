---
name: qa-lead-review-requirements
agent: qa-lead
description: "Reviews requirements for testability, completeness, and ambiguity"
---

# Review Requirements

Analyze requirements to find gaps, ambiguities, and untestable criteria before development starts.

## Process

1. Read all requirements, user stories, and acceptance criteria
2. Check each requirement against the quality checklist below
3. Flag issues with severity: blocker (stops testing), warning (needs clarification), info (suggestion)
4. For each issue, suggest a concrete improvement
5. Verify non-functional requirements are explicitly stated
6. Check for missing error scenarios and edge cases

## Template

```markdown
# Requirements Review: <feature/epic>

## Summary

- **Requirements reviewed**: <count>
- **Issues found**: <count by severity>
- **Verdict**: Ready for development / Needs revision

## Findings

### Blockers

- **<Requirement ref>**: <issue> → **Suggestion**: <improvement>

### Warnings

- **<Requirement ref>**: <issue> → **Suggestion**: <improvement>

### Info

- **<Requirement ref>**: <suggestion for improvement>

## Missing Requirements

- <gap identified> — <why it matters>

## Non-Functional Gaps

- <NFR not addressed> — <recommendation>

## Testability Assessment

| Requirement | Testable? | Issue |
|-------------|-----------|-------|
| <ref> | Yes / Partially / No | <why not, if applicable> |
```

## Quality checklist

- [ ] Unambiguous — only one possible interpretation
- [ ] Measurable — can be verified with a concrete test
- [ ] Complete — covers happy path, errors, edge cases, and permissions
- [ ] Consistent — does not contradict other requirements
- [ ] Feasible — can be implemented and tested with available resources
- [ ] Non-functional requirements stated — performance, security, accessibility

## Rules

- Review BEFORE development starts — shift-left prevents rework
- Every issue must include a concrete suggestion, not just "this is unclear"
- Testability is the primary lens — if you cannot write a test for it, it needs revision
