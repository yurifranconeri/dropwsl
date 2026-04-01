# Requirements Engineering

## Elicitation Techniques

- **Interviews**: one-on-one with stakeholders — open-ended questions, listen for pain points
- **Observation**: watch users interact with the current system — what they do, not what they say
- **Workshops**: collaborative sessions with multiple stakeholders — use dot voting, affinity mapping
- **Prototyping**: low-fidelity mockups to validate understanding before building
- **Document analysis**: review existing specs, logs, support tickets, analytics

## Stakeholder Management

Identify and classify stakeholders:

| Quadrant | Interest ↑ Power → | Strategy |
|---|---|---|
| High power, high interest | **Manage closely** | Regular updates, involve in decisions |
| High power, low interest | **Keep satisfied** | Periodic summaries, escalate risks |
| Low power, high interest | **Keep informed** | Share progress, collect feedback |
| Low power, low interest | **Monitor** | Minimal communication |

## Prioritization Frameworks

### MoSCoW

- **Must have** — non-negotiable for this release
- **Should have** — important but not critical
- **Could have** — nice to have if time permits
- **Won't have** — explicitly out of scope (this time)

### WSJF (Weighted Shortest Job First)

```
WSJF = Cost of Delay / Job Duration

Cost of Delay = User-Business Value + Time Criticality + Risk Reduction
```

Higher WSJF = do first. Prioritize high-value, short-duration items.

### RICE

```
RICE = (Reach × Impact × Confidence) / Effort
```

- **Reach**: how many users affected (per quarter)
- **Impact**: how much it matters (0.25 = minimal, 3 = massive)
- **Confidence**: how sure are we (100% = high, 50% = low)
- **Effort**: person-months

## Requirements Quality Checklist

A good requirement is:

- [ ] **Unambiguous** — one interpretation only
- [ ] **Testable** — can be verified objectively
- [ ] **Traceable** — links to a business goal or user need
- [ ] **Feasible** — technically possible within constraints
- [ ] **Necessary** — removing it would harm the product
- [ ] **Consistent** — doesn't contradict other requirements
