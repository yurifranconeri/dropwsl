---
name: po-release-notes
description: "Generates user-facing release notes from recent changes"
---

# Release Notes

## When to use

When preparing a release and stakeholders or users need a summary of what changed.

## Process

1. Gather context: read recent commits, merged PRs, closed issues, changelog
2. Group changes by category: Features, Fixes, Breaking Changes, Improvements
3. Write each entry in user-facing language â€” explain impact, not implementation
4. Highlight breaking changes prominently with migration instructions
5. Include version number and date

## Output format

```markdown
# Release Notes â€” v<version> (<date>)

## Features

- **<Feature name>**: <what users can now do>

## Fixes

- **<Fix name>**: <what was broken and how it's fixed>

## Breaking Changes

- **<Change>**: <what changed, why, and how to migrate>

## Improvements

- **<Improvement>**: <what got better>
```

## Rules

- Write for users, not developers â€” "you can now" instead of "refactored the handler"
- Every breaking change MUST include migration steps
- Don't list internal refactors, CI changes, or dev-only improvements
- Group related changes â€” don't list every commit separately
- If nothing changed in a category, omit the category entirely
