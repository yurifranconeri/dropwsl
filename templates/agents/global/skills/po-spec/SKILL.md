---
name: po-spec
description: "Creates a functional specification for a feature or epic"
---

# Functional Spec

## When to use

When a feature is complex enough to need a written spec before implementation begins.

## Process

1. Understand the problem: who has it, how often, what's the impact
2. Research context: existing solutions, constraints, dependencies
3. Define requirements: what must be true when this is done
4. Write acceptance criteria for each requirement
5. Explicitly list what's out of scope
6. Identify open questions and risks

## Output format

```markdown
# Spec: <Feature Name>

## Problem

<Who has this problem? How often? What's the impact?>

## Context

<Existing behavior, constraints, related features, prior art>

## Requirements

### R1: <Requirement name>
<Description>

**Acceptance Criteria:**
- Given ..., when ..., then ...

### R2: <Requirement name>
<Description>

**Acceptance Criteria:**
- Given ..., when ..., then ...

## Out of Scope

- <What this spec explicitly does NOT cover>

## Open Questions

- <Unresolved decisions that need stakeholder input>

## Risks

- <What could go wrong and how to mitigate>
```

## Rules

- A spec is a thinking tool â€” write it to clarify, not to document what's already clear
- Requirements describe WHAT, never HOW
- Out of scope is as important as in scope â€” it prevents scope creep
- Every open question should have a proposed answer or owner
- Keep it concise â€” if it's longer than 2 pages, split the feature
