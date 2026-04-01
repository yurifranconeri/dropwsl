# Code Review Standards

## Purpose

Code review is a quality practice that catches defects, shares knowledge, and maintains
code consistency. Reviews assess the change against team standards — not personal preferences.

## Review Dimensions

### Correctness

- Does the code do what it's supposed to do?
- Are edge cases handled (null, empty, boundary values, error paths)?
- Are concurrent access and race conditions considered (if applicable)?
- Does it handle failure gracefully (network errors, timeouts, invalid input)?

### Readability

- Are names meaningful and consistent with project conventions?
- Is the code self-documenting — minimal comments needed?
- Are functions/methods short with a single level of abstraction?
- Can a new team member understand this code without external explanation?

### Design

- Does the change follow SOLID principles?
- Is the abstraction level appropriate — not too much, not too little?
- Are dependencies explicit and injected, not hidden?
- Does the change respect existing architecture boundaries (layers, modules)?

### Security

- Is user input validated and sanitized?
- Are parameterized queries used (no string concatenation for SQL/commands)?
- Are secrets, tokens, or PII excluded from logs and error messages?
- Are authorization checks in place for protected resources?

### Performance

- Are there obvious inefficiencies (N+1 queries, unnecessary allocations, blocking I/O)?
- Is caching considered where appropriate?
- Are database queries indexed for the access patterns used?
- Is pagination used for potentially large result sets?

### Testability

- Are there tests for the new or changed behavior?
- Do tests follow the Arrange-Act-Assert pattern?
- Are tests independent and deterministic (no test order dependency)?
- Is the coverage adequate for the risk level of the change?

### Maintainability

- Will this code be easy to change in the future?
- Is complexity justified — simpler alternatives considered?
- Are magic numbers and strings extracted as named constants?
- Is error handling consistent with project patterns?

## Review Checklist

Use as a mental model, not a checkbox exercise:

- [ ] Change is scoped correctly — one logical change per PR
- [ ] Tests cover the change — happy path and error cases
- [ ] No dead code, commented-out code, or debug statements
- [ ] Naming follows project conventions
- [ ] Error handling is consistent with project patterns
- [ ] No hardcoded secrets, URLs, or environment-specific values
- [ ] Breaking changes are documented and communicated
- [ ] Dependencies added are justified and evaluated

## Feedback Etiquette

### Good feedback

- Critique the code, never the person
- Explain WHY, not just WHAT — "This could cause N+1 queries because..." not just "Fix this"
- Distinguish blockers from suggestions: prefix with `blocking:` or `nit:` or `suggestion:`
- Offer alternatives when requesting changes
- Acknowledge good patterns — positive feedback reinforces good practices

### Anti-patterns

- Bikeshedding: spending time on trivial style issues that linters should catch
- Rubber-stamping: approving without reading — defeats the purpose
- Gatekeeper mentality: blocking PRs to impose personal preferences
- Drive-by comments: dropping concerns without context or suggested solutions

## PR Size Guidelines

| Size | Lines changed | Typical review time |
|---|---|---|
| **Small** | < 100 | 15 minutes |
| **Medium** | 100–300 | 30–60 minutes |
| **Large** | 300–500 | 60–90 minutes |
| **Too large** | > 500 | Split the PR |

- Smaller PRs get better reviews — cognitive load matters
- If a PR is too large, it likely contains multiple logical changes — split by concern
- Refactoring PRs should be separate from feature PRs
