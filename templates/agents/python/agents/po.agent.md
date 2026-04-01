<!-- Fragmento de contexto Python — injetado nos global agents por agent-po.sh.
     Não é um agent template completo (sem YAML frontmatter). -->

## Product context

- This is a Python project — specs and stories should reference Python-specific tooling
- Test acceptance: `pytest` must pass for any story to be considered done
- Lint acceptance: `ruff check .` must pass — no exceptions
- Dependencies are tracked in `requirements.txt` (prod) and `requirements-dev.txt` (dev)
- When writing stories that involve API endpoints, reference FastAPI conventions (if applicable)
