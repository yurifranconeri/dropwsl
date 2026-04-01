---
applyTo: "tests/**"
---

# Test Code Rules

- Follow arrange-act-assert pattern with blank lines separating each section
- Test names describe the scenario: `test_<what>_<condition>_<expected>`
- One behavior per test function — multiple asserts are fine if testing the same behavior
- Use `@pytest.fixture` for reusable setup — put shared fixtures in `conftest.py`
- Use `@pytest.mark.parametrize` for testing multiple inputs
- Mock at boundaries only: external APIs, I/O, clock, randomness
- Use `pytest.raises(SpecificError, match="message")` for expected exceptions
- Do not test implementation details — test behavior (inputs → outputs)
- Do not write tests that depend on execution order
- Always clean up resources in fixtures (use `yield` for teardown)
