# Regression Testing

## Purpose

Regression testing verifies that existing functionality still works after changes — new features, bug fixes, refactoring, dependency updates, configuration changes.

## Impact Analysis

Before selecting regression tests, analyze what changed:

### Change categories

| Change type | Impact scope | Regression focus |
|---|---|---|
| **Bug fix** | Localized — the fixed function and callers | Unit tests around fix + integration tests for affected flow |
| **New feature** | New code + integration points | New tests + existing tests for shared components |
| **Refactoring** | Internal structure, same behavior | Full regression — behavior must be identical |
| **Dependency update** | Potentially broad | Integration tests + contract tests + security scan |
| **Config change** | Environment-specific | Smoke tests + environment validation |
| **Database migration** | Data layer and all consumers | Data integrity tests + API tests + integration tests |

### Blast radius assessment

1. Identify changed files/modules
2. Trace dependencies — what calls, imports, or depends on the changed code?
3. Map to test suites — which tests cover the affected area?
4. Add upstream and downstream tests — changes propagate in both directions

## Selecting Regression Tests

### Risk-based regression

Not all tests need to run every time. Prioritize:

1. **Always run**: tests covering the changed area (direct impact)
2. **High priority**: tests for critical business flows (payments, auth, data integrity)
3. **Medium priority**: tests for areas with historical defects
4. **Low priority**: tests for stable, low-risk areas
5. **Skip**: tests for completely unrelated areas (if confident in dependency analysis)

### Smoke vs. Full regression

| Type | When | Duration | Coverage |
|---|---|---|---|
| **Smoke** | Every commit, every deploy | Minutes | Critical path only — login, core CRUD, health check |
| **Shallow regression** | Every PR merge | 10-30 min | Smoke + changed area + high-risk areas |
| **Full regression** | Before release, after major changes | Hours | Everything |

## Automation Candidates

### Good candidates for automation

- Stable features that rarely change (high ROI)
- Repetitive checks that run on every build
- Data-driven tests with many input combinations
- Cross-browser/cross-platform compatibility checks
- API contract validations

### Poor candidates for automation

- Features under active development (constant maintenance)
- One-time exploratory checks
- Tests requiring complex visual validation
- Tests with high environment setup cost and low reuse

## Regression Test Maintenance

### Test suite health

- **Flaky tests**: quarantine immediately, fix or remove — flaky tests erode trust
- **Slow tests**: profile and optimize — slow suites get skipped
- **Redundant tests**: remove tests that add no unique coverage — overlap wastes time
- **Outdated tests**: update or remove when requirements change — failing tests that nobody investigates are worse than no tests

### Coverage gap detection

- Track which code paths have no tests
- Use mutation testing to verify tests actually detect changes
- Review test-to-requirement traceability — are any requirements untested?
- Add missing tests as bugs are found in production

## CI/CD Integration

### Pipeline stages

1. **Pre-commit**: linting, formatting, fast unit tests
2. **PR build**: unit + integration + contract tests + SAST
3. **Merge to main**: full regression + security scan + SCA
4. **Pre-deploy**: smoke tests against staging
5. **Post-deploy**: synthetic monitoring, canary validation

### Parallel execution

- Split test suite into independent shards
- Run shards in parallel to reduce total time
- Group by execution time for balanced distribution
- Ensure tests have no shared state between shards
