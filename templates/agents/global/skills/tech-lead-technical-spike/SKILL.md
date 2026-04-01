---
name: tech-lead-technical-spike
description: "Plan a technical spike â€” a time-boxed investigation to reduce uncertainty. Defines hypothesis, scope, success criteria, and decision framework."
---

## When to use

- Evaluating feasibility of a technical approach before committing
- Investigating an unfamiliar technology, library, or integration
- Reducing risk for a high-uncertainty feature
- Comparing implementation approaches with a prototype
- Answering a specific technical question that requires hands-on experimentation

## Process

1. Define the question or uncertainty the spike addresses â€” be specific
2. Formulate a hypothesis â€” what you expect to find
3. Define scope â€” what to investigate, what to explicitly exclude
4. Set success criteria â€” measurable criteria that answer the question
5. Define time-box â€” how long to investigate before making a decision
6. Identify risks â€” what could make the spike inconclusive
7. Plan the investigation â€” steps, experiments, prototypes to build
8. Define the decision framework â€” how results map to a decision

## Output format

```markdown
# Technical Spike: <Title>

## Question

<The specific question this spike answers. One clear question.>

## Hypothesis

<What we expect to find. E.g., "Library X can handle 10k concurrent connections with < 100ms P99.">

## Background

<Why this investigation is needed. What decisions depend on the outcome.>

## Scope

### In scope
- <What will be investigated>
- <What will be prototyped or measured>

### Out of scope
- <What is explicitly excluded>
- <What will NOT be built>

## Success Criteria

| Criterion | Threshold | How to measure |
|---|---|---|
| <criterion 1> | <measurable threshold> | <measurement method> |
| <criterion 2> | <measurable threshold> | <measurement method> |

## Time-box

**Duration:** <e.g., 2 days, 1 sprint>

**Deadline:** <date>

If inconclusive by deadline: <fallback decision â€” e.g., "default to Option B">

## Investigation Plan

1. <Step 1 â€” e.g., "Set up minimal prototype with Library X">
2. <Step 2 â€” e.g., "Run load test with k6/locust at 10k concurrent users">
3. <Step 3 â€” e.g., "Measure P50/P95/P99 latency and error rate">
4. <Step 4 â€” e.g., "Document findings and compare with requirements">

## Decision Framework

| Result | Decision |
|---|---|
| All criteria met | Proceed with approach â€” create ADR |
| Partial criteria met | <conditional path> |
| No criteria met | Reject approach â€” pursue alternative |

## Risks

- <What could make the spike inconclusive>
- <External dependency that might block investigation>

## Outcome (filled after spike)

### Findings

<What was discovered. Data, measurements, observations.>

### Decision

<What was decided based on findings. Link to ADR if created.>
```

## Rules

- One question per spike â€” avoid bundling multiple investigations
- Hypothesis must be falsifiable â€” "Library X is good" is not a hypothesis
- Success criteria must be measurable â€” "fast enough" is not a criterion
- Time-box is mandatory â€” spikes without deadlines become projects
- Always define a fallback decision for inconclusive results
- Outcome section is filled AFTER the spike â€” plan and result are in the same document
- Spike produces a decision, not code â€” prototypes are throwaway
