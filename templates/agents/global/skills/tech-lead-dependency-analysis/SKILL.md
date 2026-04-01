---
name: tech-lead-dependency-analysis
description: "Evaluate a library, framework, or tool. Produces an assessment report covering maintenance health, license, security, alternatives, and lock-in risk."
---

## When to use

- Evaluating a new dependency before adoption
- Reviewing whether to keep or replace an existing dependency
- Responding to a CVE or deprecation notice
- Periodic dependency health audit
- Comparing alternatives for a specific capability

## Process

1. Identify the dependency and its purpose in the project
2. Check maintenance health â€” last release, commit frequency, open issues ratio
3. Review license compatibility â€” MIT, Apache 2.0, GPL implications
4. Search for known vulnerabilities â€” CVE databases, GitHub advisories
5. Assess community and ecosystem â€” GitHub stars, downloads, Stack Overflow activity
6. Evaluate API stability â€” versioning practices, breaking change frequency, changelog quality
7. Identify alternatives â€” at least 2 comparable options
8. Assess lock-in risk â€” how deeply integrated, how hard to replace
9. Make a recommendation â€” adopt, keep, replace, or remove

## Output format

```markdown
# Dependency Evaluation: <library-name>

## Summary

| Attribute | Value |
|---|---|
| **Package** | <name> |
| **Current version** | <version in use or N/A> |
| **Latest version** | <latest stable> |
| **License** | <license type> |
| **Repository** | <URL> |
| **Last release** | <date> |
| **Recommendation** | âœ… Adopt / ðŸ”„ Keep / âš ï¸ Replace / âŒ Remove |

## Maintenance Health

| Indicator | Status |
|---|---|
| Last commit | <date> |
| Release frequency | <e.g., monthly, quarterly> |
| Open issues | <count> (ratio: <open/closed %>) |
| Open PRs | <count> |
| Contributors | <count> (bus factor: <1 or healthy?>) |
| CI/CD | âœ… / âŒ |
| Changelog | âœ… / âŒ |

## Security

| Indicator | Status |
|---|---|
| Known CVEs | <count â€” list critical ones> |
| Security policy | âœ… / âŒ (SECURITY.md, advisories) |
| Dependency chain | <depth â€” transitive dependencies count> |

## API Stability

- Semantic versioning: âœ… / âŒ
- Breaking changes in last 3 major versions: <frequency>
- Migration guides provided: âœ… / âŒ
- Deprecation policy: <documented? grace period?> 

## Alternatives

| Library | Pros | Cons | Maturity |
|---|---|---|---|
| <current> | <pros> | <cons> | <maturity> |
| <alternative 1> | <pros> | <cons> | <maturity> |
| <alternative 2> | <pros> | <cons> | <maturity> |

## Lock-in Assessment

- **Integration depth**: <shallow (wrapper) / medium (several modules) / deep (pervasive)>
- **Replacement effort**: <S / M / L / XL>
- **Abstraction possible**: <yes â€” can wrap behind interface / no â€” API is exposed throughout>
- **Data migration**: <required? format-specific data stored?>

## Recommendation

<Adopt / Keep / Replace / Remove â€” with justification.>

<If Replace: migration path, suggested alternative, phasing.>

## References

- <Package URL, CVE links, comparison articles>
```

## Rules

- Always check CVEs â€” security is non-negotiable
- License must be compatible with the project â€” GPL in a commercial project is a blocker
- Bus factor of 1 is a risk â€” note single-maintainer projects explicitly
- Even "adopt" decisions should document lock-in risk
- Alternatives section must have at least 2 options for comparison
- If recommending replacement, include a migration path â€” not just "use X instead"
