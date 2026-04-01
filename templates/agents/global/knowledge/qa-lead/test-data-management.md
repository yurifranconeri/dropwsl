# Test Data Management

## Principles

- Test data is a first-class artifact — version it, review it, maintain it
- Each test should create its own data or use a known fixture — never depend on shared mutable state
- Tests must be independent — running in any order must produce the same result
- Clean up after tests or use transaction rollback to avoid data pollution

## Data Generation Strategies

### Fixtures (static)

- Predefined data sets loaded before tests
- Good for: reference data, lookup tables, stable scenarios
- Risk: becomes stale if the schema evolves — maintain alongside migrations
- Format: SQL scripts, JSON/YAML files, factory functions

### Factories (dynamic)

- Generate data programmatically with sensible defaults and overrides
- Good for: unit and integration tests where each test needs unique data
- Pattern: `create_user(name="test", role="admin")` with optional overrides
- Libraries: Factory Boy (Python), Faker (multiple languages), Bogus (.NET)

### Synthetic data

- Statistically representative data that mimics production without real PII
- Good for: performance testing, ML training, demo environments
- Techniques: Markov chains, GANs, rule-based generators
- Validate: synthetic data must cover the same distributions and edge cases as real data

### Production snapshots

- Anonymized subset of production data
- Good for: reproducing bugs, realistic integration tests
- Requires: data masking pipeline, legal review, regular refresh

## Data Masking and Anonymization

| Technique | Description | Use case |
|---|---|---|
| **Substitution** | Replace real values with fake but realistic ones | Names, emails, phones |
| **Shuffling** | Rearrange values within a column | Preserves distribution, breaks identity |
| **Masking** | Partially hide values (e.g., `****1234`) | Credit cards, SSN display |
| **Hashing** | One-way transform — consistent but irreversible | Referential integrity across tables |
| **Tokenization** | Replace with random token, store mapping in vault | When reversibility is required |
| **Generalization** | Reduce precision (e.g., exact age → age range) | Analytics that don't need precision |
| **Nulling** | Remove value entirely | Non-essential sensitive fields |

### Rules

- NEVER use real PII in test environments
- Apply masking BEFORE data leaves production infrastructure
- Validate masked data still exercises the same code paths
- Document which fields are masked and which technique is used

## Environment-Specific Data

| Environment | Data source | Volume | Refresh |
|---|---|---|---|
| **Unit tests** | Factories/fixtures | Minimal | Every test run |
| **Integration** | Factories + test containers | Small | Every test run |
| **Staging** | Anonymized production snapshot | Production-like | Weekly/monthly |
| **Performance** | Synthetic + scaled snapshot | Production-scale | Before each test cycle |
| **Production** | Real data | Full | N/A — it's live |

## Test Data for Specific Scenarios

### Boundary values

- Generate data at min, max, and edge boundaries for every constrained field
- Include: empty strings, null, max-length strings, zero, negative, future dates, past dates

### Internationalization (i18n)

- Unicode characters, RTL text, accented characters, emoji
- Date/time in multiple timezones and formats
- Currency with different decimal separators
- Address formats from different countries

### Error scenarios

- Malformed data: truncated JSON, invalid XML, wrong encoding
- Injection payloads: SQL injection, XSS, command injection (for security testing)
- Constraint violations: duplicate keys, foreign key mismatches, null in NOT NULL
