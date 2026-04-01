
## Python-specific checks

- Type hints present on all public functions and methods
- Return types annotated (including `-> None`)
- No use of `print()` â€” should use `logging`
- `pathlib.Path` used instead of `os.path`
- Context managers used for files and connections
- No bare `except:` â€” specific exception types caught
- No mutable default arguments (`def f(items=[])` â€” use `None` + guard)
- f-strings used for formatting (not `.format()` or `%`)
- Imports managed by Ruff (no manual isort or grouping)
- No star imports (`from module import *`)
- Dataclasses or Pydantic used instead of raw dicts for structured data
