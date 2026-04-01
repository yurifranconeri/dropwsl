<!-- Fragmento de contexto Python — injetado nos global agents por agent-qa.sh.
     Não é um agent template completo (sem YAML frontmatter). -->

## Python testing context

- Test runner: **Pytest** with `pytest-cov` for coverage
- Linter: **Ruff** — `ruff check .` must pass (no lint violations in tests either)
- Property-based testing: use **Hypothesis** for data-driven test generation
- Mutation testing: use **mutmut** to verify test suite effectiveness
- Performance testing: use **Locust** for load and stress tests (if applicable)
- Contract testing: use **Pact Python** for consumer-driven contracts (if applicable)
- Dependencies in `requirements-dev.txt` — test libraries are dev dependencies
- Configuration in `pyproject.toml` — Pytest settings, coverage thresholds, Ruff rules
- Test files: `tests/` directory, files named `test_*.py`, functions named `test_*`
- Fixtures: prefer `conftest.py` for shared fixtures, factory functions over static data
- Mocking: use `unittest.mock` or `pytest-mock` — prefer dependency injection over patching
- Coverage target: define in `pyproject.toml` under `[tool.coverage.report]`
