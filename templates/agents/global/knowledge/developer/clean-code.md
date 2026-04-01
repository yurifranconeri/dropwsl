# Clean Code & SOLID Principles

## Single Responsibility (SRP)

- Each function does one thing and does it well
- If a function needs a comment explaining what it does, it is too complex — rename or split
- Each class/module has one reason to change
- Avoid god objects that know everything

## Open/Closed (OCP)

- Extend behavior by adding new code, not modifying existing code
- Use polymorphism, strategy pattern, or composition to vary behavior
- Configuration and convention reduce the need for modification

## Liskov Substitution (LSP)

- Subtypes must be substitutable for their base types without breaking behavior
- Do not override methods with incompatible signatures or side effects
- Prefer composition over deep inheritance hierarchies

## Interface Segregation (ISP)

- Do not force implementations to depend on methods they do not use
- Prefer small, focused interfaces/protocols over large ones
- Split responsibilities across multiple protocols/ABCs

## Dependency Inversion (DIP)

- High-level modules should not depend on low-level modules — both depend on abstractions
- Inject dependencies through constructor or function parameters
- This makes code testable and swappable

## Naming

- Names reveal intent: `calculate_total_price` not `calc` or `process`
- Booleans read as questions: `is_valid`, `has_permission`, `can_retry`
- Avoid abbreviations unless domain-standard (`url`, `id`, `db` are fine)
- Collections are plural: `users`, `items`, `results`
- Do not encode types in names: `user_list` → `users`

## Functions

- Prefer small functions (under 20 lines is a guideline, not a rule)
- One level of abstraction per function
- No side effects that the caller would not expect
- Prefer early return over nested conditions
- Limit parameters — more than 3 suggests the function does too much or needs a data object

## Error handling

- Do not use exceptions for control flow
- Handle errors close to where they occur
- Provide context in error messages: what happened, what was expected, what to do

## Comments

- Good code is self-documenting — comments explain WHY, not WHAT
- Do not comment out code — delete it (version control remembers)
- Update comments when code changes — stale comments are worse than no comments

## General

- No magic numbers or strings — use named constants
- Fail fast: validate preconditions at the start
- Prefer immutability: do not mutate what you do not own
- Delete dead code — unused functions, unreachable branches, TODO comments older than a sprint
