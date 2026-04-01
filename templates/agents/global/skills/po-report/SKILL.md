---
name: po-report
description: "Generates executive summaries, sprint reviews, and progress reports"
---

# Report

## When to use

When stakeholders need a status update, sprint review summary, or executive summary.

## Process

1. Gather data: completed work, metrics, blockers, risks, feedback
2. Choose the report type based on audience and purpose
3. Write with business impact â€” not technical details
4. Include next steps and decisions needed

## Report Types

### Executive Summary

For leadership. Focus on outcomes, risks, and decisions needed.

```markdown
# Executive Summary â€” <date or sprint>

## Highlights
- <Key achievement with business impact>

## Risks
- <Risk>: <impact> â€” <mitigation>

## Decisions Needed
- <Decision>: <context and options>

## Next Steps
- <What's planned next>
```

### Sprint Review

For stakeholders. Focus on what was delivered and what's next.

```markdown
# Sprint Review â€” Sprint <N> (<dates>)

## Sprint Goal
<What we set out to accomplish>

## Delivered
| Item | Status | Notes |
|---|---|---|
| <Story/Feature> | Done | <Impact or metric> |

## Not Completed
| Item | Reason | Plan |
|---|---|---|
| <Story> | <Why> | <When it will be done> |

## Metrics
- Velocity: <points completed>
- Bugs found/fixed: <N/N>

## Feedback Captured
- <Stakeholder feedback â†’ backlog item created>

## Next Sprint
- Goal: <next sprint goal>
- Key items: <top 3 stories>
```

### Progress Report

For regular status updates. Focus on what's done, what's blocked, what's next.

```markdown
# Progress Report â€” <date>

## Completed
- <What was done and why it matters>

## In Progress
- <What's being worked on>

## Blocked
- <What's stuck and what's needed to unblock>

## Next Steps
- <What's coming next>
```

## Rules

- Lead with impact, not activity â€” "reduced deploy time by 40%" not "refactored CI pipeline"
- Blockers must have an owner and a proposed resolution
- Decisions needed must include enough context for the audience to decide
- Keep it brief â€” one page per report type
