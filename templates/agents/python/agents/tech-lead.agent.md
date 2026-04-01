<!-- Fragmento de contexto Python — injetado nos global agents por agent-tech-lead.sh.
     Não é um agent template completo (sem YAML frontmatter). -->

## Python architecture context

- Use `pyproject.toml` (PEP 621) as the single source of project metadata and tool configuration
- Prefer `src/` layout — application code under `src/<package>/`, tests under `tests/`
- Type annotations with `mypy --strict` — treat type errors as bugs
- FastAPI for HTTP APIs — Pydantic for validation, async handlers for I/O-bound operations
- SQLAlchemy 2.0 style — mapped_column, DeclarativeBase, async sessions when applicable
- `uv` for dependency management — lock files for reproducible builds
- Hexagonal / Ports & Adapters — domain logic depends on abstractions, infrastructure adapts
- Dependency injection via constructor — no global state, no service locators
- Structured logging with `structlog` or `logging.config.dictConfig` — JSON format in production
- Ruff for linting and formatting — single tool, fast, replaces black + isort + flake8
