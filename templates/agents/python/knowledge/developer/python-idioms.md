# Python Idioms & Patterns

## Type hints

- All public functions and methods must have type annotations (parameters + return)
- Use `str | None` syntax (Python 3.10+), not `Optional[str]`
- Use `list[str]`, `dict[str, int]` (built-in generics), not `List`, `Dict` from typing
- For complex types, create type aliases: `UserId = int`
- Use `Protocol` for structural subtyping (duck typing with type safety)
- Use `TypeVar` for generic functions
- Private/internal helpers: type hints are recommended but not mandatory

## Data structures

- Use `dataclasses` for plain data containers with no validation
- Use `Pydantic BaseModel` when validation is needed (API input/output, config)
- Use `NamedTuple` for immutable records
- Use `Enum` for fixed sets of values — never magic strings
- Avoid raw dicts for domain objects — they hide structure and prevent type checking

## String handling

- f-strings for interpolation: `f"Hello, {name}"`
- `str.join()` for building strings from lists: `", ".join(items)`
- Triple-quoted strings for multi-line
- raw strings (`r"..."`) for regex patterns and Windows paths

## Collections and iteration

- List comprehensions for simple transformations: `[x.upper() for x in names]`
- Generator expressions for large sequences: `sum(x**2 for x in range(10_000))`
- `enumerate()` instead of manual counter: `for i, item in enumerate(items)`
- `zip()` for parallel iteration — use `strict=True` in Python 3.10+
- `dict.get(key, default)` instead of `if key in dict`
- Use `collections.defaultdict`, `Counter`, `deque` when appropriate
- Never modify a collection while iterating over it

## Context managers

- Always use `with` for files, locks, connections, transactions
- Create custom context managers with `contextlib.contextmanager` or `__enter__`/`__exit__`
- Use `contextlib.suppress(ExceptionType)` instead of empty try/except

## Error handling

- Define custom exception hierarchy for the project (inherit from project base exception)
- Catch specific exceptions: `except ValueError` not `except Exception`
- Use `raise ... from e` to preserve the exception chain
- Use `logging.exception()` inside except blocks (auto-includes traceback)
- Never use exceptions for control flow

## Pattern matching (Python 3.10+)

- Use `match`/`case` for complex branching on structure
- Prefer over long if/elif chains when matching on type or structure
- Use guard clauses in case statements: `case x if x > 0:`

## Async

- Use `async`/`await` for I/O-bound operations (network, file, database)
- Never mix sync blocking calls inside async functions (use `asyncio.to_thread()` if needed)
- Use `asyncio.gather()` for concurrent I/O
- Async context managers: `async with`

## Imports

- Ruff manages import sorting — do not manually organize
- Prefer absolute imports over relative
- Import modules, not individual names (except for common utilities)
- Avoid star imports: `from module import *`

## Performance

- Profile before optimizing: `cProfile`, `line_profiler`, `py-spy`
- Use generators for large data pipelines
- Use `functools.lru_cache` for expensive pure functions
- Prefer `set` for membership tests over `list`
- Connection pooling for database/HTTP clients
