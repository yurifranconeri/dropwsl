---
name: developer-testing
description: "Writes and runs tests using Pytest"
---

# Testing

## When to use

When asked to write tests, improve coverage, or verify behavior.

## Tools

- Test runner: `pytest`
- Coverage: `pytest --cov --cov-report=term-missing`
- Run single test: `pytest tests/test_file.py::test_name -v`

## Process

1. Identify the code to test â€” read it fully
2. Determine test scenarios: happy path, edge cases, error paths
3. Write tests following arrange-act-assert
4. Use fixtures for setup, parametrize for multiple inputs
5. Run: `pytest`
6. Check coverage: are important paths covered?

## What to test

- Public function behavior (inputs â†’ outputs)
- Edge cases: empty, None, zero, boundary values, invalid input
- Error paths: does it raise the right exception?
- Integration points: database queries, API calls (mocked at boundary)

## What NOT to test

- Private implementation details
- Third-party library behavior (Pytest, FastAPI internals)
- Trivial getters/setters with no logic
- Constants and configuration values
