---
name: developer-refactor
description: "Refactors code to improve structure without changing behavior"
---

# Refactor

## When to use

When asked to refactor, simplify, or improve code structure.

## Principles

- Refactoring changes structure, never behavior
- Tests must pass before AND after â€” if no tests exist, write them first
- One refactoring at a time â€” do not combine multiple transformations
- If it is not broken and not blocking a task, do not refactor (YAGNI)

## Techniques

- **Extract function**: when a block of code does something that deserves a name
- **Inline function**: when the function body is as clear as its name
- **Rename**: when a name does not communicate intent
- **Simplify conditional**: replace nested if/else with guard clauses or early returns
- **Remove duplication**: extract shared logic (only when duplicated 3+ times)
- **Introduce parameter object**: when a function takes too many related args
- **Replace flag argument**: when a boolean parameter changes the function behavior, split into two functions
- **Move responsibility**: when a function/method lives in the wrong class/module

## Process

1. Understand the current behavior by reading tests (or writing them if missing)
2. Identify the specific smell or improvement
3. Apply one transformation
4. Run tests
5. Repeat if needed

## What NOT to do

- Do not refactor and add features at the same time
- Do not refactor without test coverage
- Do not rename everything at once â€” incremental changes are safer
- Do not abstract prematurely â€” wait for the third instance of duplication
