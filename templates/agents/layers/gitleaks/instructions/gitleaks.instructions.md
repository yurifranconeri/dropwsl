---
applyTo: "**"
---

# Gitleaks Rules

- Gitleaks pre-commit hook is active — commits with secrets will be blocked
- Never hardcode API keys, tokens, passwords, or connection strings
- Use environment variables via `.env` file (which is in `.gitignore`)
- If Gitleaks blocks a commit with a false positive, add the pattern to `.gitleaks.toml` allowlist
- Run manually: `gitleaks detect --source .`
