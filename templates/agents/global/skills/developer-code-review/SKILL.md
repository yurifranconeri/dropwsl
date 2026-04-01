---
name: developer-code-review
description: "Reviews code for security, bugs, performance, and maintainability"
---

# Code Review

## When to use

When asked to review code, a diff, a PR, or recent changes.

## Process

1. Read the full context â€” not just the changed lines, but surrounding code
2. Check each category below
3. Report findings with severity, location, and suggested fix
4. If nothing is wrong, confirm explicitly â€” do not invent issues

## Security

- Input validation: are external inputs sanitized before use?
- Injection: SQL, command, path traversal, template injection
- Secrets: hardcoded credentials, API keys, connection strings
- Authentication/authorization: are access checks in place?
- Data exposure: are sensitive fields filtered from responses/logs?

## Bugs

- Null/None/undefined not handled on code paths that can produce them
- Off-by-one errors in loops, slices, ranges
- Race conditions in concurrent/async code
- Exceptions swallowed silently (empty catch/except blocks)
- Resource leaks (files, connections, locks not properly closed)
- Logic errors: inverted conditions, missing edge cases

## Performance

- N+1 queries (loop that makes one query per iteration)
- Unnecessary allocations in hot paths
- Blocking I/O in async context
- Missing pagination on unbounded queries
- Redundant computation that could be cached or hoisted

## Maintainability

- Naming: do names reveal intent?
- Complexity: can the logic be simplified?
- Duplication: is the same logic repeated elsewhere?
- Coupling: does this change force changes in unrelated code?
- Testability: can this code be tested in isolation?

## Output format

For each finding:
- **Severity**: critical / warning / info
- **Location**: file and line
- **Issue**: what is wrong
- **Fix**: how to resolve it
