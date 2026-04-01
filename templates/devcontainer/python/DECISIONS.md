# Technical Decisions

> This document explains the reasoning behind each choice in this template.
> It can be removed without affecting the project's functionality.

---

## Python & Venv

| Decision | Reason |
|---|---|
| Python 3.12 | Stable version with active support (Python has no official LTS program) |
| venv at `/opt/venv` | Fixed path works in any terminal, `docker exec`, CI. Does not depend on VS Code variables |
| `[build-system]` in pyproject.toml | PEP 517/518 -- without it `pip install -e .` fails |

## Docker

| Decision | Reason |
|---|---|
| **Dev: bookworm (full)** | Compilers, headers, debug tools -- needed for troubleshooting |
| **Prod: slim-bookworm** | Smaller attack surface (~120MB vs ~350MB), no unnecessary tools |
| **Same Python version** | Ensures behavior parity between dev and prod |
| Multi-stage build (prod) | Builder installs deps -> runtime receives only the venv. No pip/setuptools/wheel in final image |
| OCI labels | `image.source`, `image.revision`, `image.version` -- traceability in registry and CI |
| `PYTHONDONTWRITEBYTECODE=1` | Avoids `.pyc` on read-only filesystem (containers) |
| `PYTHONUNBUFFERED=1` | Logs appear immediately in `docker logs` (no buffer) |
| Non-root user (prod) | `appuser` -- basic security, required by scanners and corporate policies |
| HEALTHCHECK | Docker/orchestrator detects unhealthy container and restarts automatically |
| exec form in CMD | PID 1 = python -> receives SIGTERM directly from Docker for clean shutdown |

## .dockerignore

| Decision | Reason |
|---|---|
| Excludes `.git/`, `tests/`, IDE, caches | Reduces build context and image size |
| **Includes** `pyproject.toml` | Required for `pip install .` and `importlib.metadata` at runtime |
| Excludes `requirements-dev.txt` | Dev deps (pytest, ruff) are not copied by the production Dockerfile (which uses selective COPY) |

## Ruff (linter + formatter)

| Rule | What it detects |
|---|---|
| E, W, F | Standard errors and warnings (pycodestyle + pyflakes) |
| I | Import sorting (replaces isort) |
| N | Names outside PEP 8 |
| UP | Old syntax that can be modernized |
| B | Common bugs (flake8-bugbear) |
| S | Security vulnerabilities (bandit) |
| A | Shadowing builtins (`list`, `id`, etc.) |
| T20 | `print()` -- in production use logging |
| C4, SIM, PIE, RET, RSE | Simplifiable code, unnecessary return/raise |

> S101 (assert) and T20 (print) are allowed in `tests/` via per-file-ignores.

## Pytest

| Decision | Reason |
|---|---|
| `-x` (fail-fast) | Stops at the first failure -- immediate feedback, no waiting for the entire suite |
| `--strict-markers` | Typo in `@pytest.mark.xxx` becomes an error instead of silently ignored |
| `--strict-config` | Typo in `pyproject.toml` becomes an error (e.g., `addops` instead of `addopts`) |
| `pythonpath = ["."]` | Imports work without `pip install -e .` in flat layout |
| `pytest-cov` | `pytest --cov` generates integrated coverage report |

## Coverage

| Decision | Reason |
|---|---|
| `omit = */venv/*` | Ignores venv regardless of path (`/opt/venv`, `.venv`) |
| `fail_under = 0` | Starts with no minimum requirement -- adjust as the project matures |

## Git (configured by dropwsl)

| Config | Reason |
|---|---|
| `init.defaultBranch = main` | Modern corporate standard |
| `core.autocrlf = input` | Prevents CRLF in the repository (safety net beyond `.gitattributes`) |
| `push.autoSetupRemote = true` | Avoids `--set-upstream` on first push |
| `pull.ff = only` | Pull only accepts fast-forward -- no accidental merge commits |
| `fetch.prune = true` | Automatically removes deleted remote branches |
| `diff.colorMoved = zebra` | Highlights moved code in diff (easier code review) |

### Strategy: Feature Branch + Squash Merge

```
main ──●──────────────────●── A (squash)
        \                /
         feature-x ──●──●
```

1. Create branch: `git checkout -b feature-x`
2. Work and commit normally (WIP, fix, etc.)
3. Before PR, update: `git fetch origin && git rebase origin/main`
4. Push: `git push` (or `--force-with-lease` if already pushed)
5. Open PR -> reviewer approves -> **Squash merge** on GitHub/Azure DevOps
6. Local: `git checkout main && git pull` (pure fast-forward)

> Configure on GitHub/Azure DevOps: **allow only squash merge** on the `main` branch.
> If pull fails (non-fast-forward), do `git rebase origin/main` and try again.

## .gitattributes

| Decision | Reason |
|---|---|
| `* text=auto eol=lf` | Normalizes line endings to LF for all text files |
| `*.lock linguist-generated` | Lock files don't appear in GitHub diff (reduces PR noise) |
| Explicit binaries (png, jpg) | Prevents Git from trying to diff binary files |

## .editorconfig

| Decision | Reason |
|---|---|
| 4 spaces for Python | PEP 8 |
| 2 spaces for JSON/YAML/TOML | Community convention |
| Tab for Makefile | Required by Make syntax |
| `trim_trailing_whitespace = false` for `.md` | Markdown uses 2 trailing spaces for line break |

## Dev Container Lifecycle

| Hook | When it runs | What it does |
|---|---|---|
| `postCreateCommand` | On container creation | Installs deps -> `pip install -e .` (if src/) -> ruff check -> pytest |
| `postStartCommand` | Every time the container starts | `chmod 666 /var/run/docker.sock` -- fixes permissions on the socket mounted from the host (GID differs between host/container) |

## Entry Point (`--with src`)

| Decision | Reason |
|---|---|
| `[project.scripts]` in pyproject.toml | Creates a CLI command with the project name (e.g., `my-service`) |
| CLI name with hyphen, package with underscore | PyPA convention -- CLI uses `my-service`, Python uses `my_service` |
| `CMD ["my-service"]` in Dockerfile | Entry point is the package contract -- if module/function changes, CMD doesn't break |
| `pip install -e .` in Dev Container | `post-create.sh` detects `src/` and installs automatically -- entry point available in terminal |
| `pip install --no-deps .` in builder (prod) | Installs the package without reinstalling deps (already installed via requirements.txt) |

> Src layout without `[project.scripts]` is an installable package that doesn't execute anything.
> The entry point is the piece that connects `pip install` -> CLI command -> Docker `CMD`.

## Mypy (`--with mypy`)

| Decision | Reason |
|---|---|
| `strict = true` | Enables all checks -- catches type bugs before running the code |
| `disallow_untyped_defs = true` | Forces type hints on every function -- self-documenting code |
| `warn_return_any = true` | Warns when a function implicitly returns `Any` |
| Check in `post-create.sh` | Shift-left -- type errors appear right at container setup |
| `--ignore-missing-imports` | Libs without stubs (e.g., some Azure SDKs) don't block the check |

> Mypy is the TypeScript equivalent for Python -- checks types without running the code.

## Supply-Chain Security

| Decision | Reason |
|---|---|
| `pip-compile --generate-hashes` | Generates requirements.txt with SHA256 hashes for each package |
| `pip install --require-hashes` | Build fails if the hash doesn't match (protects against tampering) |
| Kind with SHA256 verification | Binary validated before installing |
| GPG keys for apt repos | Docker, kubectl, Azure CLI, gh -- all with verified keyring |

> See `requirements.txt` for usage instructions with hashes.
