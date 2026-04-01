<!-- Fragmento de contexto Python — injetado nos global agents por agent-developer.sh.
     Não é um agent template completo (sem YAML frontmatter). -->

## Python

- This is a Python 3.12 project
- Linter and formatter: Ruff (replaces flake8, black, isort)
- Test runner: Pytest with pytest-cov
- Project runs inside a Docker-based Dev Container
- Dependencies: `requirements.txt` (prod) and `requirements-dev.txt` (dev)
- Configuration: `pyproject.toml` (Ruff rules, Pytest settings, project metadata)
- Use `logging` module — never `print()` for operational output
- All public functions must have type hints
- Prefer f-strings for string formatting
- Use context managers (`with`) for resource management
- Prefer `pathlib.Path` over `os.path`
- Use dataclasses or Pydantic models for structured data — avoid raw dicts for domain objects
