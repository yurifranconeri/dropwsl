---
name: po-sprint-review
agent: po
description: "Generates a sprint review summary with delivered items and metrics"
---

# Sprint Review

Generate a sprint review report for stakeholders.

## Process

1. Ask for: sprint number, dates, sprint goal
2. Gather delivered items: merged PRs, closed issues, completed stories
3. Identify items not completed and reasons
4. Collect metrics: velocity, bugs, feedback
5. Capture stakeholder feedback as new backlog items
6. State next sprint goal and key items

## Template

```markdown
# Sprint Review — Sprint <N> (<start> – <end>)

## Sprint Goal
<What we set out to accomplish>

## Delivered
| Item | Status | Impact |
|---|---|---|
| <Story/Feature> | Done | <User-facing impact> |

## Not Completed
| Item | Reason | Plan |
|---|---|---|
| <Story> | <Why> | <Carry to next sprint / reprioritize> |

## Metrics
- Stories completed: <N>
- Bugs found/fixed: <N/N>

## Feedback
- <Feedback point → action taken or backlog item created>

## Next Sprint
- Goal: <next sprint goal>
- Top items: <top 3 priorities>
```
