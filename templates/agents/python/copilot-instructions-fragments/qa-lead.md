## Quality

- Test strategy, plans, and quality reports live in `docs/`
- Test cases use structured format: precondition, input, steps, expected result
- Acceptance criteria follow Given/When/Then (Gherkin) format
- Test runner: Pytest with pytest-cov — `pytest --cov --cov-report=term-missing`
- Linter: Ruff — `ruff check .` must pass on test code too
- Non-functional requirements must be measurable (SLO-style targets)
- The QA Lead does not write code — when implementation is needed, delegate to @developer
- Bug reports must include reproduction steps, actual vs expected, and severity
- Exploratory testing uses time-boxed charters with structured debriefs
