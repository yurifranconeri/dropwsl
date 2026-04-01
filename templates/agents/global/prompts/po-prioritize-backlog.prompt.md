---
name: po-prioritize-backlog
agent: po
description: "Prioritizes backlog items using MoSCoW or WSJF"
---

# Prioritize Backlog

Prioritize backlog items by business value and urgency.

## Process

1. List current backlog items (from issues, docs, or user input)
2. For each item, assess: user value, time criticality, risk reduction, effort
3. Apply MoSCoW categorization or calculate WSJF scores
4. Present the prioritized list with rationale
5. Identify items to cut or defer

## MoSCoW Output

```markdown
# Backlog Prioritization — <date>

## Must Have (this release)
| Item | Rationale |
|---|---|
| <Item> | <Why it's mandatory> |

## Should Have (important, not critical)
| Item | Rationale |
|---|---|
| <Item> | <Why it's important> |

## Could Have (if time permits)
| Item | Rationale |
|---|---|
| <Item> | <Why it's nice to have> |

## Won't Have (explicitly deferred)
| Item | Rationale |
|---|---|
| <Item> | <Why it's deferred> |
```

## WSJF Output

```markdown
# WSJF Prioritization — <date>

| Item | User Value | Time Criticality | Risk Reduction | Cost of Delay | Duration | WSJF | Rank |
|---|---|---|---|---|---|---|---|
| <Item> | <1-10> | <1-10> | <1-10> | <sum> | <1-10> | <score> | <#> |
```

## Rules

- Prioritize by business value, not technical complexity
- Every "Must Have" must have a clear justification
- "Won't Have" is a decision, not a failure — make it explicit
- If everything is "Must Have", nothing is — challenge the classification
