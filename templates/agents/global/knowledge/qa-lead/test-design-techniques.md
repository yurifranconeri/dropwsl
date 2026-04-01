# Test Design Techniques

## Specification-Based (Black-Box)

### Equivalence Partitioning (EP)

Divide inputs into groups (partitions) where the system behaves the same way. Test one representative from each partition.

- **Valid partitions**: inputs the system should accept
- **Invalid partitions**: inputs the system should reject
- Reduces test count without losing coverage
- Apply to: numeric ranges, string lengths, enum values, date ranges

Example: age field (0-150) → partitions: `<0` (invalid), `0-150` (valid), `>150` (invalid)

### Boundary Value Analysis (BVA)

Test at the edges of equivalence partitions — bugs cluster at boundaries.

- Test: min-1, min, min+1, max-1, max, max+1
- Apply to every numeric, date, or length constraint
- Combine with EP for efficient coverage

### Decision Table Testing

For business rules with multiple conditions and outcomes:

1. List all conditions (inputs)
2. List all actions (outputs)
3. Create a table with all condition combinations
4. Identify the expected action for each combination
5. Collapse rules with identical outcomes (don't-care conditions)

Best for: authorization rules, pricing logic, workflow transitions

### State Transition Testing

For systems with defined states and events triggering transitions:

1. Identify all states
2. Identify all events (triggers)
3. Draw state transition diagram
4. Derive test cases covering: every state, every transition, invalid transitions

Best for: order lifecycle, payment flows, user account status, session management

### Pairwise / Combinatorial Testing

When many parameters combine (config options, API params):

- Full combinatorial is impractical (exponential explosion)
- Pairwise covers all 2-way interactions — typically catches 70-90% of combination bugs
- Use tools (PICT, AllPairs) to generate minimal test sets
- Extend to 3-way or 4-way for higher-risk areas

### Classification Tree Method

Visualize input space as a tree:

- Root = system under test
- Branches = input classifications (dimensions)
- Leaves = classes within each dimension
- Test cases = one leaf per dimension combined

Useful for complex domains where partitions interact.

## Experience-Based Techniques

### Error Guessing

Use domain knowledge and experience to predict likely defects:

- Null/empty values, zero, negative numbers
- Boundary conditions the spec didn't mention
- Race conditions in concurrent operations
- Off-by-one errors in loops and pagination
- Unicode, special characters, injection strings
- Network timeouts, partial failures, retry storms

### Exploratory Testing

Simultaneous learning, test design, and execution:

1. **Charter**: define a time-boxed mission (e.g., "Explore payment flow focusing on edge cases — 45 min")
2. **Session**: execute the charter, take notes, log findings
3. **Debrief**: report bugs found, coverage achieved, new charters identified

### Checklist-Based Testing

Maintain reusable checklists for recurring test concerns:

- API checklist: auth, pagination, error responses, rate limiting, versioning
- Security checklist: injection, XSS, CSRF, auth bypass, sensitive data exposure
- Accessibility checklist: screen reader, keyboard navigation, color contrast, alt text
- Performance checklist: response time, throughput, memory, CPU under load

## Choosing Techniques

| Situation | Recommended technique |
|---|---|
| Numeric ranges, dates, lengths | EP + BVA |
| Complex business rules | Decision tables |
| Workflow / lifecycle | State transition |
| Many configuration options | Pairwise |
| Unknown unknowns | Exploratory testing |
| Common mistake patterns | Error guessing |
| Recurring validation areas | Checklists |
