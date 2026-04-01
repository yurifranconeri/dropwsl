---
name: tech-lead-create-adr
agent: tech-lead
description: "Create an Architecture Decision Record from a decision question."
---

Create an ADR (Architecture Decision Record) for the given technical decision.

## Process

1. Read existing ADRs in `docs/adr/` to determine the next number
2. Analyze the codebase to understand context and constraints
3. Research at least 2–3 options for the decision
4. Evaluate options against decision drivers
5. Produce ADR in MADR format using the `create-adr` skill

## Template

```
Create an ADR for: <decision question>

Context: <project or feature context>
Constraints: <any known constraints>
```

## Rules

- Always include at least 2 options — a decision with one option is not a decision
- Context must explain WHY the decision is needed
- Consequences must include trade-offs (at least one "Bad" consequence)
