# Test Strategy

## Test Levels (Pyramid)

Organize tests in layers — more at the bottom, fewer at the top:

| Level | Speed | Scope | When to use |
|---|---|---|---|
| **Unit** | Fast (ms) | Single function/class | Business logic, algorithms, validations |
| **Integration** | Medium (s) | Multiple components | Database queries, API client calls, message handlers |
| **Contract** | Medium (s) | Interface between services | Consumer-driven contracts (Pact), schema validation |
| **E2E / System** | Slow (min) | Full system flow | Critical user journeys, smoke tests |

- The pyramid is a guideline, not a rule — adjust proportions based on the system architecture
- Honeycomb shape (more integration) may be appropriate for microservices
- Trophy shape (more integration than unit) may be appropriate for frontend-heavy apps
- Focus on writing expressive tests with clear boundaries, not debating proportions

## Risk-Based Testing

Prioritize test effort by business impact and failure probability:

### Risk Matrix

| | Low impact | Medium impact | High impact |
|---|---|---|---|
| **High probability** | Medium priority | High priority | Critical |
| **Medium probability** | Low priority | Medium priority | High priority |
| **Low probability** | Minimal | Low priority | Medium priority |

### Risk factors

- **Business impact**: revenue loss, regulatory violation, user safety, reputation damage
- **Technical complexity**: new technology, complex algorithms, concurrency, external dependencies
- **Change frequency**: frequently modified code needs more regression coverage
- **Historical defects**: areas with past bugs are more likely to have new ones
- **Integration points**: boundaries between systems are high-risk by nature

## Automation Strategy

### Automate when

- Tests run in CI/CD and need fast feedback (regression)
- The scenario is stable and unlikely to change frequently
- The test exercises a critical business path that must never break
- Manual execution is tedious and error-prone (many data combinations)

### Keep manual when

- Exploratory testing — discovering unknown unknowns
- Usability and accessibility evaluation
- The UI changes frequently and automation maintenance cost exceeds value
- One-time validation that won't be repeated

### Automation pyramid

- **Unit**: fast, isolated, high volume — most automation effort here
- **API / Integration**: validate contracts and integrations — moderate volume
- **UI / E2E**: only critical user journeys — minimal volume, high maintenance cost

## Test Environments

- **Local / Dev Container**: unit tests, linting, fast integration tests
- **CI pipeline**: full test suite on every PR — gate for merge
- **Staging**: E2E tests, performance tests, contract tests against real services
- **Production**: synthetic monitoring, canary deployments, feature flag validation

## Entry and Exit Criteria

### Entry criteria (start testing)

- Requirements reviewed and testable
- Code deployed to test environment
- Test data available
- Dependencies accessible (APIs, databases, services)

### Exit criteria (stop testing)

- All critical test cases executed and passed
- No open critical or high-severity defects
- Test coverage meets agreed threshold
- Non-functional requirements validated
- Risk accepted for known issues (documented)
