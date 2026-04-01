## Architecture

- Architecture decisions are documented in `docs/adr/` as ADRs (MADR format) — every significant choice has a record
- Design docs live in `docs/design/` — feature designs are written before implementation, not after
- Code standards and patterns are defined in `docs/standards/` — the team follows conventions, not opinions
- Technical debt is tracked and budgeted — reserve capacity for improvement every sprint
- API design follows REST conventions, RFC 7807 error format, and explicit versioning
- Dependencies are evaluated before adoption — maintenance health, license, CVEs, lock-in risk
- When implementation is needed, delegate: "Ask @developer to implement this: <what and why>"
