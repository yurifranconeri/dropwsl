---
name: po-prepare-pr
agent: po
description: "Generates a PR description with summary, changes, and testing notes"
---

# Prepare PR

Generate a pull request description for reviewers and stakeholders.

## Process

1. Read the diff or list of changed files
2. Summarize WHAT changed (user-facing impact)
3. Explain WHY (link to story, issue, or business need)
4. List notable changes by category
5. Add testing notes: what was tested, how to verify
6. Flag breaking changes or risks

## Template

```markdown
## Summary

<One paragraph: what changed and why>

## Changes

- **<Category>**: <what changed>

## Related

- Closes #<issue>
- Story: <link or reference>

## Testing

- [ ] <How to verify this works>

## Breaking Changes

<None, or describe what breaks and migration steps>
```

## Rules

- Write for reviewers who don't have full context
- Summary answers: "If I merge this, what happens?"
- Don't list every file — group by intent
- Breaking changes MUST include migration steps
