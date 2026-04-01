---
name: po-sdlc-check
agent: po
description: "Validates that the current workflow follows SDLC order"
---

# SDLC Check

Review the current project state and advise on workflow order.

## Process

1. Check: are there user stories or specs defined? (look for docs/, specs/, issues)
2. Check: are there architecture decisions? (look for ADRs, design docs)
3. Check: is implementation underway? (look for recent code changes)
4. Check: are there test plans? (look for test-plans/, quality artifacts)
5. Identify gaps and suggest the next step with the appropriate agent
6. Typical order: @po (requirements) → @tech-lead (design) → @developer (implement) → @qa-lead (validate)
