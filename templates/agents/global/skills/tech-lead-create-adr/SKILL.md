---
name: tech-lead-create-adr
description: "Create an Architecture Decision Record (ADR) in MADR format. Captures context, decision drivers, options considered, outcome, and consequences."
---

## When to use

- A significant technical decision needs to be documented
- Choosing a technology, pattern, library, or approach
- A previous decision needs to be superseded
- Stakeholders need to understand WHY a choice was made

## Process

1. Identify the decision to be made â€” frame it as a question or problem statement
2. Read existing ADRs to understand numbering and context (`docs/adr/` or `ADRs/`)
3. Gather context: constraints, requirements, quality attributes affected
4. List decision drivers â€” what matters most for this decision
5. Enumerate at least 2â€“3 options with pros and cons for each
6. Choose the best option and justify based on drivers
7. Document consequences: good, bad, and neutral
8. Assign the next sequential ADR number
9. Save as `docs/adr/ADR-NNNN-<kebab-case-title>.md`

## Output format

```markdown
# ADR-NNNN: <Decision Title>

## Status

Proposed

## Context

<What is the issue or situation that motivates this decision?
What forces are at play? What constraints exist?
Link related ADRs if applicable.>

## Decision Drivers

- <Driver 1 â€” e.g., "Team needs to ship within 2 weeks">
- <Driver 2 â€” e.g., "Must support horizontal scaling">
- <Driver 3>

## Considered Options

### Option 1: <Name>

<Description of the approach.>

- âœ… <pro>
- âœ… <pro>
- âŒ <con>

### Option 2: <Name>

<Description of the approach.>

- âœ… <pro>
- âŒ <con>
- âŒ <con>

### Option 3: <Name>

<Description of the approach.>

- âœ… <pro>
- âŒ <con>

## Decision Outcome

Chosen option: **"Option X"**, because <justification tied to decision drivers>.

### Consequences

#### Good

- <positive consequence>

#### Bad

- <negative trade-off accepted>

#### Neutral

- <side effect that is neither good nor bad>

## References

- <Link to related documentation, research, or prior ADRs>
```

## Rules

- One decision per ADR â€” never bundle multiple choices
- Context section must explain WHY the decision is needed, not just WHAT it is
- List at least 2 options â€” a decision with only 1 option is not a decision
- Consequences must include at least one "Bad" item â€” every choice has trade-offs
- Never modify an Accepted ADR â€” create a new one that supersedes it
- Number sequentially â€” never reuse ADR numbers
