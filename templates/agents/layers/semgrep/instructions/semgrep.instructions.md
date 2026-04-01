---
applyTo: "**/*.py"
---

# Semgrep Rules

- Semgrep SAST is configured for this project (`.semgrep.yml`)
- Run: `semgrep scan --config auto .`
- Fix all findings before committing — do not suppress without justification
- Semgrep catches: injection, insecure deserialization, hardcoded secrets, insecure crypto
- Complement to Ruff (style/lint) — Semgrep focuses on security vulnerabilities
