# Contributing

This guide explains how to participate in the project.

## Prerequisites

- Windows 10/11 with WSL 2
- Git configured with `core.autocrlf = input`
- Familiarity with Bash scripting

## How to Contribute

1. **Fork** the repository
2. Create a descriptive branch: `git checkout -b feat/my-feature`
3. Make your changes
4. Validate syntax: `bash -n lib/common.sh lib/validate.sh lib/clean.sh lib/core/*.sh lib/project/*.sh lib/layers/**/*.sh dropwsl.sh`
5. Run ShellCheck (if available): `shellcheck lib/common.sh lib/validate.sh lib/clean.sh lib/core/*.sh lib/project/*.sh lib/layers/**/*.sh dropwsl.sh`
6. **Run tests:** `./tests/run-tests.sh all` (see [tests/README.md](tests/README.md) for details)
7. Commit with a clear message: `git commit -m "feat: add support for X"`
8. Open a **Pull Request** describing what changed and why

## Running Tests

```bash
# Unit + Integration — run before every commit (~12s)
./tests/run-tests.sh all

# Only unit tests (~5s)
./tests/run-tests.sh unit

# Only a specific layer
./tests/run-tests.sh integration --filter "layer_fastapi"

# PowerShell tests (Windows, outside WSL)
Invoke-Pester tests/pester/ -Output Detailed
```

Every code change (`.sh`, `.ps1`, `.cmd`) must include or update at least one corresponding test in `tests/`. Exceptions: docs-only, config-only (no new field), refactors with no behavior change, and core installers (covered by smoke/E2E).

Full details: [tests/README.md](tests/README.md)

## Code Conventions

| Rule | Example |
|------|---------|
| Install functions: `install_<tool>()` | `install_docker()`, `install_kubectl()` |
| Config functions: `configure_<service>()` | `configure_gcm()`, `configure_git_defaults()` |
| Layer functions: `apply_layer_<name>()` (hyphens to underscores) | `apply_layer_fastapi()`, `apply_layer_mcp_github()` |
| Local variables with `local` | `local version="${1}"` |
| Logging via `log`/`warn`/`die`/`die_hint` (common.sh) | `log "installing..."` |
| `die_hint` for contextual errors (4 args) | `die_hint "Docker failed" "daemon stopped;permission" "1. Reinstall;2. Check group" "systemctl status docker"` |
| Guard clause (anti double-source) | `[[ -n "${_MOD_SH_LOADED:-}" ]] && return 0` |
| No external dependencies | Only coreutils + bash built-ins |

## Module Structure

- **CMD wrappers** (`.cmd`): `install.cmd`, `uninstall.cmd`, `dropwsl.cmd` — entry points that bypass ExecutionPolicy
- **PowerShell** (`.ps1`): `install.ps1`, `uninstall.ps1`, `dropwsl.ps1` — actual logic, called by `.cmd`
- **Bash** (`.sh`): `dropwsl.sh`, `lib/**/*.sh` — run inside WSL

Each module in `lib/` follows this pattern:

```bash
#!/usr/bin/env bash
# lib/core/example.sh — Short description

[[ -n "${_EXAMPLE_SH_LOADED:-}" ]] && return 0
_EXAMPLE_SH_LOADED=1

install_example() {
    if has_cmd example; then
        log "example already installed: $(example --version || true)"
        return 0
    fi
    log "Installing example..."
    # logic
}
```

## Commits

Use [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` — new feature
- `fix:` — bug fix
- `docs:` — documentation only
- `refactor:` — refactoring with no behavior change
- `chore:` — maintenance (CI, deps, configs)

## Issues

- Use the issue template when available
- Include: Windows version, WSL distro, error output
- Add labels when possible (`bug`, `enhancement`, `docs`)

## License

By contributing, you agree that your contributions will be licensed under the same license as the project.
