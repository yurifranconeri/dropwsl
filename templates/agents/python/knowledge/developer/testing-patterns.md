# Testing Patterns (Pytest)

## Structure

- Test files mirror source structure: `src/services/user.py` → `tests/services/test_user.py`
- Test file names start with `test_`: `test_user.py`
- Test function names start with `test_`: `test_create_user_with_valid_data`
- Test names describe the scenario: `test_<what>_<condition>_<expected>`

## Arrange-Act-Assert

Every test follows this pattern:
1. **Arrange**: set up inputs, dependencies, expected values
2. **Act**: call the function under test (one action per test)
3. **Assert**: verify the result

Keep each section visually separated with a blank line.

## Fixtures

- Use `@pytest.fixture` for reusable setup — not `setUp()` methods
- Prefer function-scoped fixtures (default) for isolation
- Use `session` scope for expensive resources (database connections, containers)
- Put shared fixtures in `conftest.py` (auto-discovered by Pytest)
- Fixtures can depend on other fixtures — compose them
- Use `yield` fixtures for setup + teardown

## Parametrize

- Use `@pytest.mark.parametrize` to test multiple inputs with the same logic
- Provide descriptive `ids` for each parameter set
- Combine parametrize with fixtures for matrix testing

## Assertions

- Use plain `assert` — Pytest rewrites them with detailed failure messages
- For exceptions: `with pytest.raises(ValueError, match="expected message")`
- For approximate floats: `assert result == pytest.approx(3.14)`
- Assert one concept per test — multiple asserts are fine if testing the same behavior

## Mocking

- Prefer real implementations over mocks when feasible
- Mock at the boundary: external APIs, I/O, clock, randomness
- Use `unittest.mock.patch` as context manager or decorator
- Always assert that mocks were called as expected
- Use `spec=True` to prevent mocks from accepting non-existent attributes

## Edge cases to test

- Empty input (empty string, empty list, None)
- Boundary values (0, 1, -1, max, min)
- Invalid input (wrong type, out of range, malformed)
- Error paths (exception raised, service unavailable, timeout)
- Concurrency (if applicable): race conditions, deadlocks

## Coverage

- Run: `pytest --cov --cov-report=term-missing`
- Aim for meaningful coverage, not 100% — test logic, not getters/setters
- Missing lines in the report indicate untested code paths

## Anti-patterns

- Do not test implementation details — test behavior (inputs → outputs)
- Do not write tests that depend on execution order
- Do not test the framework (Pytest, FastAPI) — test YOUR code
- Do not mock everything — over-mocking makes tests brittle and useless
- Do not ignore flaky tests — fix them or delete them
