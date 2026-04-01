## Stack

- Python 3.12
- Linter and formatter: Ruff
- Tests: Pytest with pytest-cov
- Container: Docker multi-stage (dev + prod, non-root)
- Dependencies: `requirements.txt` (prod), `requirements-dev.txt` (dev)
- Configuration: `pyproject.toml` (Ruff rules, Pytest settings)

## Project structure

- `main.py` — application entry point
- `tests/` — test files (mirrors source structure)
- `tests/conftest.py` — shared Pytest fixtures
- `.devcontainer/` — Dev Container config (managed by scaffold, do not modify)
- `pyproject.toml` — project metadata and tool configuration
- `Dockerfile` — multi-stage build (dev target + prod target)

## Build and validation

- Lint: `ruff check .`
- Format: `ruff format .`
- Test: `pytest`
- Test with coverage: `pytest --cov --cov-report=term-missing`
- Run: `python main.py`
