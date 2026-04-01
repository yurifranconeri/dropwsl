---
name: tech-lead-code-standards
description: "Create a coding standards document for a language or project area. Covers conventions, patterns, anti-patterns, and linter configuration."
---

## When to use

- Starting a new project and defining conventions
- Onboarding new team members who need a reference
- Standardizing practices across multiple services/modules
- Resolving recurring code review debates
- Adopting a new pattern or deprecating an old one

## Process

1. Identify the scope â€” language, framework, or project area
2. Read existing codebase to understand current patterns in use
3. Define naming conventions â€” variables, functions, classes, files, directories
4. Define structural patterns â€” file organization, module boundaries, layering
5. Define error handling patterns â€” when to catch, what to return, logging
6. Define testing conventions â€” naming, structure, coverage expectations
7. Identify anti-patterns to avoid â€” with rationale
8. Map conventions to linter rules where possible â€” automate enforcement
9. Keep it concise â€” standards nobody reads are useless

## Output format

```markdown
# Coding Standards: <Language / Area>

## Naming Conventions

| Element | Convention | Example |
|---|---|---|
| Variables | <convention> | <example> |
| Functions | <convention> | <example> |
| Classes | <convention> | <example> |
| Constants | <convention> | <example> |
| Files | <convention> | <example> |
| Directories | <convention> | <example> |

## File Organization

```
project/
â”œâ”€â”€ src/
â”‚   â”œâ”€â”€ <module>/
â”‚   â”‚   â”œâ”€â”€ <pattern>
```

<Rules for file placement, module boundaries, import conventions.>

## Patterns

### <Pattern Name>

<When to use this pattern. Brief example or reference.>

```<language>
# Example code showing the pattern
```

## Anti-Patterns

### <Anti-Pattern Name>

âŒ **Don't do this:**
```<language>
# Bad example
```

âœ… **Do this instead:**
```<language>
# Good example
```

**Why:** <rationale â€” what problem the anti-pattern causes>

## Error Handling

- <Convention for error handling in this language/framework>
- <When to use exceptions vs return values>
- <Logging requirements for errors>

## Testing Conventions

- <Test file naming: test_<module>.py, <module>.test.ts>
- <Test function naming: test_<behavior>_<scenario>>
- <Structure: Arrange-Act-Assert>
- <Coverage expectations: minimum, per-module>

## Linter Configuration

<Map conventions to linter rules. Reference the config file.>

| Rule | Setting | Rationale |
|---|---|---|
| <rule name> | <value> | <why this setting> |

## References

- <Style guides, linter docs, team agreements>
```

## Rules

- Keep it concise â€” a 50-page document nobody reads is worse than no document
- Automate what you can â€” linter rules > document rules
- Include rationale â€” "because the style guide says so" is not a reason
- Anti-patterns must show both the wrong and right way â€” contrast is how people learn
- Update when conventions change â€” stale standards cause confusion
- Focus on project-specific decisions â€” don't repeat what's in the language's official style guide
