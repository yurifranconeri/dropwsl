---
name: qa-lead-quality-report
description: "Generates a quality status report for a sprint, release, or project"
---

# Quality Report

## When to use

When stakeholders need a summary of quality status â€” test results, coverage, defects, risks, and readiness assessment.

## Process

1. Gather test execution results (pass/fail/skip/blocked)
2. Collect coverage metrics (code coverage, requirement coverage)
3. Summarize open defects by severity and status
4. Assess non-functional test results (performance, security, accessibility)
5. Identify outstanding risks and blockers
6. State the quality verdict: ready / conditionally ready / not ready

## Output format

```markdown
# Quality Report: <sprint/release/feature>

**Date**: <date>
**Status**: ðŸŸ¢ Ready / ðŸŸ¡ Conditionally Ready / ðŸ”´ Not Ready

## Test Execution Summary

| Level | Total | Pass | Fail | Skip | Blocked | Pass rate |
|-------|-------|------|------|------|---------|-----------|
| Unit | | | | | | |
| Integration | | | | | | |
| Contract | | | | | | |
| E2E | | | | | | |
| **Total** | | | | | | |

## Coverage

- **Code coverage**: <percentage> (target: <threshold>)
- **Requirement coverage**: <stories tested / total stories>
- **Risk coverage**: <critical risks covered / total critical risks>

## Defects

| Severity | Open | In Progress | Resolved | Total |
|----------|------|-------------|----------|-------|
| Critical | | | | |
| High | | | | |
| Medium | | | | |
| Low | | | | |

### Critical/High Open Defects

- <defect ID>: <summary> â€” <impact> â€” <ETA>

## Non-Functional Results

- **Performance**: <status and key metrics>
- **Security**: <status and findings count>
- **Accessibility**: <status and compliance level>

## Risks

| Risk | Impact | Mitigation | Status |
|------|--------|------------|--------|
| <risk> | <impact> | <action> | Open/Mitigated |

## Verdict

<Rationale for the status. What conditions must be met for conditional readiness.>
```

## Rules

- The verdict must be supported by data â€” never give "ready" with open critical defects
- Report both coverage and uncoverage â€” what was NOT tested matters as much as what was
- Defects must include severity and business impact, not just technical description
- If conditionally ready, list the explicit conditions that must be met before release
