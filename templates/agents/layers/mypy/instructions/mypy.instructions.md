---
applyTo: "**/*.py"
---

# mypy Rules

- All functions must have type annotations on parameters AND return type (including `-> None`)
- Use `str | None` syntax, not `Optional[str]`
- Use built-in generics: `list[str]`, `dict[str, int]`, not `List`, `Dict` from typing
- Use `Protocol` for structural subtyping when you need duck-typing with type safety
- Use `TypeVar` for generic functions that preserve input types
- Fix all mypy errors before committing — do not use `# type: ignore` without an error code and comment
- Run: `mypy .`
