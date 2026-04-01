# Technical Debt

## The Metaphor

Technical debt (Ward Cunningham, 1992) is the implied cost of future rework caused by choosing
an expedient solution now instead of a better approach that would take longer. Like financial debt,
it accrues **interest** — the longer it exists, the harder and more expensive changes become.

## Fowler's Technical Debt Quadrant

| | **Deliberate** | **Inadvertent** |
|---|---|---|
| **Reckless** | "We don't have time for design" | "What's layering?" |
| **Prudent** | "We must ship now and deal with consequences" | "Now we know how we should have done it" |

- **Reckless + Deliberate**: worst kind — knowingly cutting corners with no plan to fix
- **Reckless + Inadvertent**: team lacks knowledge — invest in training and code review
- **Prudent + Deliberate**: strategic — acceptable if the debt is tracked and scheduled for repayment
- **Prudent + Inadvertent**: natural — learning during development reveals better designs

Only prudent deliberate debt is strategically acceptable — and only with a repayment plan.

## Categories

| Category | Examples | Detection |
|---|---|---|
| **Code debt** | Duplicated code, long methods, poor naming, missing abstractions | Linter warnings, code smells, code review findings |
| **Design debt** | God classes, tight coupling, circular dependencies, missing patterns | Static analysis, dependency graphs, architecture tests |
| **Architecture debt** | Wrong architecture style, missing boundaries, scaling bottlenecks | Fitness functions, load tests, team friction |
| **Infrastructure debt** | Manual deployments, missing monitoring, outdated OS/runtime | Deployment frequency, MTTR, incident post-mortems |
| **Documentation debt** | Missing ADRs, outdated README, undocumented APIs | Onboarding friction, repeated questions |
| **Test debt** | Low coverage, missing integration tests, flaky tests | Coverage reports, test suite reliability metrics |
| **Dependency debt** | Outdated libraries, known CVEs, deprecated APIs | `dependabot`, `trivy`, `npm audit`, `pip-audit` |

## Identification

### Code Smells (indicators, not proof)

- **Long method/function**: doing too much — extract smaller functions
- **Large class/module**: multiple responsibilities — split by cohesion
- **Feature envy**: function uses another module's data more than its own — move it
- **Shotgun surgery**: one change requires edits in many places — missing abstraction
- **Primitive obsession**: using strings/ints for domain concepts — use value objects
- **Middle man**: class delegates everything — remove the indirection
- **Speculative generality**: abstractions nobody uses — remove them (YAGNI)

### Automated Detection

- **Linters**: Ruff, ESLint, Roslyn Analyzers — catch style and complexity issues
- **Static analysis**: SonarQube, Semgrep — detect structural problems
- **Dependency scanning**: Trivy, Dependabot — find outdated/vulnerable dependencies
- **Architecture tests**: ArchUnit, Fitness Functions — enforce structural rules

## Measurement

### Debt Ratio

```
Debt Ratio = Remediation Cost / Development Cost
```

- Below 5%: manageable — normal maintenance
- 5–15%: concerning — schedule dedicated remediation time
- Above 15%: critical — debt is actively slowing development

### Interest Rate

The cost of NOT fixing the debt:
- How much extra time does each feature take because of this debt?
- How many bugs are caused by this area?
- How much onboarding time is wasted explaining workarounds?

High-interest debt (slows every change) should be paid off first, regardless of principal.

## Governance

### Sprint Allocation

- Reserve 15–20% of sprint capacity for debt reduction
- Make debt work visible — track as regular backlog items
- Tie debt items to business impact: "Fixing X will reduce deploy time from 30min to 5min"

### Debt Budget

- Set a threshold: "No module should exceed cyclomatic complexity of 15"
- Enforce with automated fitness functions in CI
- New debt is acceptable only if: tracked, justified, and scheduled for repayment

### Refactoring vs Rewrite

| Refactoring | Rewrite |
|---|---|
| Incremental improvement | Start from scratch |
| Low risk, continuous delivery | High risk, feature freeze |
| Preserves working behavior | May introduce new bugs |
| Always prefer this | Only when refactoring is impossible |

- Default to refactoring — Strangler Fig pattern for large-scale modernization
- Rewrite only when: the system cannot be incrementally changed, AND the domain is well-understood
