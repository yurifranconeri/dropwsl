---
name: qa-lead-exploratory-charter
description: "Creates a time-boxed exploratory testing charter with mission, scope, and heuristics"
---

# Exploratory Charter

## When to use

When structured exploratory testing is needed â€” discovering unknown unknowns, testing new features without formal test cases, or investigating a suspicious area.

## Process

1. Identify the target area and the reason for exploration
2. Define the mission â€” what are we trying to learn or find?
3. Set a time box (typically 30-90 minutes)
4. Choose relevant heuristics and oracles
5. Define the scope boundaries â€” what is in and out
6. After the session: document findings, bugs, and new charters

## Output format

```markdown
## Exploratory Charter

### Mission

Explore <target area> focusing on <focus> to discover <what we're looking for>.

### Time Box

<duration> minutes

### Target

- **Area**: <feature/module/component>
- **Build/Version**: <version under test>
- **Environment**: <where to test>

### Scope

- **In**: <what to explore>
- **Out**: <what NOT to explore>

### Heuristics

Apply these lenses during exploration:

- <heuristic 1> â€” <what to look for>
- <heuristic 2> â€” <what to look for>

### Oracles

How to judge if something is wrong:

- <oracle 1> â€” <how it helps>
- <oracle 2> â€” <how it helps>

### Notes (fill during session)

| Time | Observation | Type | Severity |
|------|-------------|------|----------|
| | | Bug / Question / Risk / Idea | |

### Session Debrief

- **Findings**: <summary of what was discovered>
- **Bugs filed**: <list of issues created>
- **Coverage**: <what was explored vs what remains>
- **New charters**: <follow-up charters identified>
- **Confidence**: High / Medium / Low â€” <rationale>
```

## Common Heuristics

- **SFDPOT**: Structure, Function, Data, Platform, Operations, Time
- **Boundaries**: min/max values, empty inputs, special characters
- **Interruptions**: cancel mid-flow, timeout, lose connection
- **Concurrency**: multiple users, simultaneous operations
- **State transitions**: valid and invalid sequences of actions

## Common Oracles

- **Specification**: does it match documented requirements?
- **Consistency**: does it behave the same as similar features?
- **History**: has this area broken before? Same way?
- **User expectation**: would a reasonable user expect this behavior?
- **Comparable product**: how do competitors handle this?

## Rules

- Always set a time box â€” exploratory testing without a boundary becomes unfocused
- Take notes during the session, not after â€” observations fade quickly
- File bugs immediately when found â€” don't batch them for later
- Every charter should end with a debrief â€” even if nothing was found, that is a finding
