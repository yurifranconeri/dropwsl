---
name: tech-lead-design-feature
agent: tech-lead
description: "Create a technical design document for a feature or system."
---

Create a design document for the specified feature or system.

## Process

1. Understand the requirements — read PRD, user stories, or ask for clarification
2. Identify system boundaries, components, and key quality attributes
3. Design data model and API contracts
4. Analyze cross-cutting concerns — security, observability, error handling
5. Document trade-offs and alternatives considered
6. Produce design doc using the `design-doc` skill

## Template

```
Design: <feature or system name>

Requirements: <what needs to be built>
Constraints: <known constraints — tech stack, timeline, integrations>
Quality priorities: <e.g., "performance over flexibility", "security-first">
```

## Rules

- Goals and Non-Goals must be explicit
- Include at least one alternative in Trade-offs section
- Data model must show key relationships
- API design follows REST conventions
- Risks section is mandatory — every design has uncertainties
