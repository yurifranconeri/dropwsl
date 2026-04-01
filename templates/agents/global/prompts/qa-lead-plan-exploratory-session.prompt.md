---
name: qa-lead-plan-exploratory-session
agent: qa-lead
description: "Creates an exploratory testing charter for a target area"
---

# Plan Exploratory Session

Create a time-boxed exploratory testing charter to discover unknown issues.

## Process

1. Ask for: what area to explore, why (new feature, risky area, reported issues)
2. Define the mission — what we're trying to learn or find
3. Set a time box (30-90 minutes)
4. Select relevant heuristics (SFDPOT, boundaries, interruptions, concurrency)
5. Define oracles — how to judge correctness
6. Set scope boundaries

## Template

```markdown
# Exploratory Charter: <area>

## Mission

Explore <target> focusing on <focus> to discover <goal>.

## Time Box

<duration> minutes

## Target

- **Area**: <feature/module>
- **Environment**: <where>

## Heuristics

- <heuristic> — <what to look for>
- <heuristic> — <what to look for>

## Oracles

- <oracle> — <how it helps judge correctness>

## Scope

- **In**: <what to explore>
- **Out**: <what to skip>

## Session Log

| Time | Observation | Type |
|------|-------------|------|
| | | Bug / Question / Risk / Idea |

## Debrief

- **Findings**: <summary>
- **Bugs filed**: <issues>
- **New charters**: <follow-ups>
- **Confidence**: High / Medium / Low
```

## Rules

- Always set a time box — unbounded exploration loses focus
- Log observations during the session, not after
- File bugs immediately — don't batch for later
- End every session with a debrief
