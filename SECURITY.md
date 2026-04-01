# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| latest  | Yes       |

## Reporting a Vulnerability

If you discover a security vulnerability in dropwsl, **please do not open a public issue.**

Instead, report it privately:

1. **GitHub Security Advisory** (preferred): Go to the [Security tab](../../security/advisories) and click "Report a vulnerability"
2. **Email**: Send details to the repository owner (visible on the GitHub profile)

### What to include

- Description of the vulnerability
- Steps to reproduce
- Affected version(s)
- Potential impact

### Response timeline

- **Acknowledgement**: within 72 hours
- **Assessment**: within 1 week
- **Fix or mitigation**: depends on severity, typically within 2 weeks for critical issues

### Scope

The following are in scope:

- Shell injection via user-supplied input (project names, paths, config values)
- Privilege escalation (WSL ↔ Windows boundary)
- Secret exposure (credentials, tokens in generated files or logs)
- Supply chain issues (compromised dependencies, insecure downloads)
- Unsafe file operations (symlink attacks, TOCTOU)

The following are **out of scope**:

- Issues in upstream tools (Docker, kubectl, helm, etc.) — report to their maintainers
- Issues requiring physical access to the machine
- Social engineering

### Disclosure

We follow [coordinated disclosure](https://en.wikipedia.org/wiki/Coordinated_vulnerability_disclosure). We will credit reporters in the release notes unless they prefer to remain anonymous.
