# User Stories

## INVEST Criteria

Every story must be:

- **Independent** — no implicit dependencies on other stories
- **Negotiable** — describes the need, not the solution
- **Valuable** — delivers benefit to a user or stakeholder
- **Estimable** — clear enough for the team to size
- **Small** — completable in one sprint
- **Testable** — has acceptance criteria that can be verified

## Story Format

```
As a <role>,
I want <goal>,
so that <benefit>.
```

- The **role** is a real user persona, not "user" or "developer"
- The **goal** describes what the user wants to accomplish
- The **benefit** explains why — the business value

## Acceptance Criteria

Use Given/When/Then (Gherkin) for behavior-driven criteria:

```
Given <precondition>
When <action>
Then <expected result>
```

Or use a checklist for simpler stories:

```
- [ ] User can see the list of items
- [ ] Empty state shows a helpful message
- [ ] List updates without page reload
```

## Definition of Done

A story is done when:

1. All acceptance criteria pass
2. Code is reviewed and merged
3. Tests cover the new behavior
4. Documentation is updated (if user-facing)
5. No known regressions

## Anti-patterns

- **Epic disguised as story**: if it takes more than one sprint, split it
- **Technical task as story**: "refactor the database" is not a story — find the user value
- **Solution in the story**: "use Redis for caching" is HOW, not WHAT
- **Missing acceptance criteria**: if you can't test it, you can't ship it
- **Dependent stories**: if story B can't start until story A is done, they're not independent
