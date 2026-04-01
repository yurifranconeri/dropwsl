---
name: qa-lead-test-cases
description: "Designs test cases using formal techniques for a given requirement"
---

# Test Cases

## When to use

When a requirement, user story, or acceptance criterion needs concrete test cases with inputs, steps, and expected results.

## Process

1. Read the requirement and acceptance criteria
2. Identify input variables and their constraints (ranges, types, enums)
3. Apply Equivalence Partitioning â€” divide inputs into valid and invalid groups
4. Apply Boundary Value Analysis â€” test at edges of each partition
5. If multiple conditions interact, build a Decision Table
6. If there is a lifecycle/workflow, apply State Transition testing
7. If many parameters combine, consider Pairwise coverage
8. Add error guessing â€” common mistakes the spec doesn't mention
9. Map each test case back to the requirement it validates

## Output format

```markdown
## Test Cases: <requirement/story reference>

### TC-01: <descriptive name>
- **Precondition**: <setup required>
- **Input**: <input values>
- **Steps**:
  1. <action>
  2. <action>
- **Expected**: <observable result>
- **Technique**: EP / BVA / Decision Table / State Transition / Error Guessing
- **Priority**: Critical / High / Medium / Low

### TC-02: <descriptive name>
...
```

## Quality checks

- [ ] Happy path is covered
- [ ] Error/invalid inputs are covered
- [ ] Boundary values are tested (min, max, edges)
- [ ] Each test case has one clear expected result
- [ ] Every acceptance criterion has at least one test case
- [ ] Techniques used are documented per test case
- [ ] Priority reflects risk â€” critical paths = critical priority
