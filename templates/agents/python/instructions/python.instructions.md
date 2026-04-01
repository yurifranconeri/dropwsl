---
applyTo: "**/*.py"
---

# Python Code Rules

- All public functions and methods must have type annotations (parameters and return type)
- Use `logging` module for operational output — never `print()`
- Use `pathlib.Path` instead of `os.path` for file operations
- Use f-strings for string formatting
- Use context managers (`with`) for all resource management (files, connections, locks)
- Catch specific exceptions — never bare `except:` or `except Exception:`
- Use `raise ... from e` to preserve exception chains
- Define constants for magic numbers and strings
- Prefer early return and guard clauses over nested conditions
- Ruff is the linter and formatter — do not add flake8, black, or isort configurations
