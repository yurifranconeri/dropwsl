# Copilot Instructions — dropwsl

## Stance

- **Do not be a yes-man.** If a decision violates project principles, introduces regression risk, or adds unnecessary complexity — challenge it with data: show the tradeoff, the risk, or the violated principle. Execute only after the user decides with full context.
- If the request aligns with project principles, execute without ceremony.

## Project in 30 seconds

dropwsl provisions a complete dev environment on WSL with a single command. It installs Docker, kubectl, kind, helm, Azure CLI, GitHub CLI, configures Git + GCM, and scaffolds projects with ready-to-use Dev Containers.

**Philosophy:** WSL handles infra (Docker, k8s tooling). Languages and runtimes live **inside containers**, isolated per project. VS Code connects via Remote WSL + Dev Containers.

## Architecture

```
dropwsl/
├── *.cmd / *.ps1          # Windows layer — thin wrappers + WSL adaptation
├── dropwsl.sh             # Bash orchestrator — parses args, sources lib/, routes actions
├── config.yaml            # Declarative config — tools, versions, toggles
├── VERSION                # Semver, single line
├── lib/
│   ├── common.sh          # Logging, helpers, YAML parser (pure bash, no yq/jq)
│   ├── validate.sh        # Post-install validation (OK/FAIL/WARN)
│   ├── clean.sh           # Tool removal (--clean, --clean-soft)
│   ├── wsl-helpers.ps1    # Shared PowerShell helpers (dot-sourced)
│   ├── core/              # 1 file = 1 tool installer
│   ├── project/           # Scaffold, new project, layer orchestration, workspaces
│   └── layers/            # Optional layers (auto-discovered by directory)
│       ├── shared/        # Cross-language (agents, MCP, DevSecOps, compose)
│       └── python/        # Python-specific (fastapi, streamlit, postgres, redis, azure-*, etc.)
├── templates/
│   ├── agents/            # AI agent templates (global, per-language, per-layer)
│   ├── devcontainer/      # Dev Container templates (1 dir = 1 language)
│   └── layers/            # Layer template assets (fragments, snippets, file templates)
└── tests/                 # bats (unit/integration/e2e) + Pester (PowerShell)
```

### Windows / WSL boundary

`.cmd` files are one-liners that bypass ExecutionPolicy and call the corresponding `.ps1`.

`.ps1` files are the **adaptation layer** — all path conversion, CRLF→LF, encoding logic lives here. The `.sh` files **never** adapt to Windows.

`install.ps1` requires Admin. `dropwsl.ps1` does not (proxy only).

### Bash sourcing order

`dropwsl.sh` sources in this exact order:
1. `lib/common.sh` (must be first — defines log, helpers)
2. `lib/validate.sh`
3. `lib/clean.sh`
4. `lib/core/*.sh` (glob)
5. `lib/project/*.sh` (glob)

Then `load_config()` overrides defaults with `config.yaml` values.

## Mandatory conventions

### Guard clause (anti double-source)

Every `.sh` in `lib/` must have on the second line:

```bash
[[ -n "${_FILENAME_SH_LOADED:-}" ]] && return 0
_FILENAME_SH_LOADED=1
```

### Function naming

| Type | Pattern | Example |
|------|---------|---------|
| Install | `install_<tool>()` | `install_docker` |
| Configure | `configure_<service>()` | `configure_gcm` |
| Layer | `apply_layer_<name>()` | `apply_layer_fastapi` |
| Private | `_prefix()` | `_remove_snap_kubectl_if_any` |

Tool names use hyphens and map directly to `config.yaml`.

### Idempotency

Every install/layer function must be safe to re-run: check-before-install with `has_cmd` + early return. Scaffold never overwrites existing files (no-clobber).

### Logging

```bash
log "message"       # info
warn "message"      # non-fatal warning
die "message"       # error + exit 1
die_hint "msg" "causes" "solutions" "manual cmd"  # error with diagnostic
```

### Variables and error handling

- Always `local` for function variables.
- `set -euo pipefail` **only** in `dropwsl.sh` — never in sourced modules.
- Modules use `return`, never `exit` (except `die()`).
- Always double-quote variables: `"$var"`, never bare `$var`.
- Temp files: use `make_temp` — trap cleans up automatically, never `rm` manually.
- HTTP: always `curl_retry` (3 retries with exponential backoff), never raw `curl`.

## Anti-patterns

1. Never put Windows adaptation logic in `.sh` files — that is the `.ps1` wrapper's job.
2. Never use `exit` in modules — use `return` (they are sourced; exit kills the entire process).
3. Never use `set -euo pipefail` in modules — only in `dropwsl.sh`.
4. Never use `curl` directly — use `curl_retry`.
5. Never `rm` temp files — use `make_temp` and let the trap clean up.
6. Never depend on yq/jq/python to parse YAML — the parser is pure bash.
7. Never overwrite existing files in scaffold — no-clobber is the rule.
8. Never add a tool without a toggle in `config.yaml` — everything is config-driven.
9. Never create ad-hoc scripts or manual workarounds — all fixes must be reproducible via official entry-points.
10. Never suggest manual commands as workarounds — if something needs manual intervention, the code is wrong.
11. Never use reserved automatic variables as PowerShell parameter names (`$Args`, `$Input`, `$Error`, `$Host`).
12. Never make multiple `wsl.exe` calls when one suffices — combine check + exec in a single `bash -c`.
13. Never ignore `$LASTEXITCODE` after external executables — always check and handle.
14. Never execute git commands that modify the repository without explicit user approval.
15. Never make a layer aware of another layer — no cross-layer detection, grep, or inference. Use only explicit pipeline contracts and canonical artifacts.

**Clarification on #15:** detecting **canonical artifacts** (compose.yaml exists? `.env.example` has `# -- dropwsl:local-infra --`?) is valid — these are pipeline contracts. What's forbidden is detecting *which layer* created them (e.g., `grep "fastapi" compose.yaml` to branch behavior).

## Language-specific rules

### Bash — sed

**Always escape variables before sed substitution:**

```bash
local sed_safe="${var//\\/\\\\}"
sed_safe="${sed_safe//&/\\&}"
sed_safe="${sed_safe//|/\\|}"
sed -i "s|old|${sed_safe}|g" "$file"
```

**Multi-line insertion/replacement — always use `make_temp` + `sed r`:**

```bash
local tmp; tmp="$(make_temp)"
cat > "$tmp" <<'EOF'
line1
line2
EOF
sed -i "/^pattern$/r ${tmp}" "$file"
```

Never use `sed a\`, `sed c\`, or `\n` inline for multi-line operations — they cause silent corruption.

**Never use `\n` literal to visually break long lines** — bash does not interpret `\n` in plain string context. Each line must be a real line.

**Use `grep -F` for literal strings** containing regex metacharacters (`.`, `[`, `]`, `*`, `+`, `?`).

**Use `local IFS` + `set -f`** when iterating over delimited strings to prevent IFS leak and glob expansion.

### PowerShell

- **PS 5.1 only** — no null-coalescing (`??`), no ternary (`? :`), no pipeline chain (`&&`).
- **UTF-8 with BOM required** for all `.ps1` files — PS 5.1 reads BOM-less files as ANSI.
- **ASCII only in user-visible output** — no em-dashes, accents, or curly quotes in Write-Host/Write-Error/Write-Warning.
- **.NET regex, not POSIX** — use `\uFEFF` not `\x{FEFF}`, use `[char]0xFEFF` not multi-byte sequences.
- Use `PositionalBinding=$false` in proxy scripts.
- Always check `$LASTEXITCODE` after external executables.

### Batch (.cmd)

Read VERSION with `for /f "usebackq tokens=*" %%A in ("%~dp0VERSION")` — never `set /p` (retains `\r`).

When calling executables via WSL interop, do not use escaped quotes for arguments without spaces — they are passed literally.

## Modes: standalone vs workspace

dropwsl creates projects in two modes. The mode is determined by the presence of `--service`:

- **Standalone** (default): `dropwsl new my-app python` — one project, one repo, one Dev Container.
- **Workspace**: `dropwsl new platform --service api python` — multiple services share one repo, one compose, one `.env`.

### Structural differences

| Aspect | Standalone | Workspace |
|--------|-----------|-----------|
| Project path | `~/projects/{name}/` | `~/projects/{workspace}/services/{service}/` |
| `.devcontainer/` | `{project}/.devcontainer/` | `{workspace}/.devcontainer/{service}/` |
| `compose.yaml` | `{project}/compose.yaml` | `{workspace}/compose.yaml` (root, shared) |
| `.env` / `.env.example` | Per-project | Workspace root (merged from all services) |
| Git init | Per-project | Workspace root only |
| Port assignment | — | Auto-incremented via `_workspace_next_port()` (8001, 8002, ...) |

### How `new_project()` orchestrates each mode

**Standalone:** scaffold → apply layers → done.

**Workspace:**
1. `workspace_init()` creates skeleton (once, idempotent): `services/`, `.devcontainer/`, empty `compose.yaml` with named network, `.env`, `.gitignore`, `README.md`, git repo.
2. Calculate port for this service.
3. Scaffold into `services/{service}/`.
4. Replace scaffold's `.devcontainer/` with `workspace_devcontainer()` output at `{workspace}/.devcontainer/{service}/`.
5. Copy workspace `compose.yaml` → service dir (so layers modify a local copy).
6. Apply layers.
7. Move modified `compose.yaml` back to workspace root.
8. Merge service `.env.example` lines into workspace `.env.example` (dedup).
9. Inject service into workspace compose via `workspace_compose_service()`.

### Workspace signaling to layers

`DROPWSL_WORKSPACE` environment variable is set to the workspace path during layer application. Layers that need mode-awareness (e.g., `compose`) check this variable — never infer mode from directory structure.

### Rules

- Never hardcode `.devcontainer/` paths — always use `$devcontainer_dir` (4th layer argument).
- Never assume `compose.yaml` location — in workspace mode it lives at workspace root, not in the service dir.
- Workspace-aware behavior must check `$DROPWSL_WORKSPACE`, never probe directory layout.
- Each `--service` call is additive — calling `dropwsl new platform --service worker python` after `--service api` adds a second service without destroying the first.

## Layers

- Resolution: `lib/layers/<lang>/<layer>.sh` → fallback `lib/layers/shared/<layer>.sh`.
- **Metadata** (between guard clause and function): `_LAYER_PHASE`, `_LAYER_CONFLICTS`, `_LAYER_REQUIRES`.
- **Phases** (fixed order): `structure` → `framework` → `quality` → `infra` → `infra-inject` → `test` → `tooling` → `security` → `devtools` → `agents`.
- Layers that **create** artifacts consumed by other layers must be in an **earlier** phase.
- All layers are validated **before** any are applied (atomicity).
- **devcontainer_dir:** every layer accessing `.devcontainer/` must use `$devcontainer_dir` (4th argument). Never hardcode paths — in workspace mode the devcontainer lives in `.devcontainer/<service>/`.
- **README isolation:** a layer must never detect, infer, or branch behavior based on the presence of another layer. It may only act on explicit pipeline contracts and canonical artifacts.

### Layers and compose in each mode

- **Standalone:** layers write `compose.yaml` directly in `$project_path`. The `compose` layer creates and owns the compose file.
- **Workspace:** `workspace_init()` creates the structural compose at workspace root. Layers modify a **temporary copy** inside the service dir (copy-in → apply → copy-back). The `compose` layer signals local infra intent — it does not create or own the structural compose.

## Templates

### Base templates

The last argument in `dropwsl new my-app python` is a **base template**, not a language. A base template defines the complete Dev Container foundation: Dockerfile (multi-stage), devcontainer.json, post-create.sh, starter files, gitignore, and default tooling. Today `python` is the only base; future bases could be `dotnet`, `node`, `django`, etc.

Base templates live in `templates/devcontainer/<base>/`. The scaffold copies the entire directory to the project, then layers modify it.

### Template assets

```
templates/
├── devcontainer/<base>/     # Base templates — full Dev Container scaffold
├── layers/<scope>/<layer>/
│   ├── templates/           # Complete files rendered via render_template (no-clobber)
│   └── fragments/           # Partial content injected into existing files
└── agents/<scope>/          # AI agent definitions (global, per-language, per-layer)
```

- **Template** (`templates/`): a complete file copied to the project. Rendered with `render_template`, which replaces `{{VARIABLE}}` placeholders. No-clobber — never overwrites existing files.
- **Fragment** (`fragments/`): a partial block appended or inserted into an existing file. Injected via `inject_fragment` (append with dedup) or `inject_fragment_at` (insert at section marker). The first non-empty line is the dedup guard.

### File manipulation operations

Layers modify project artifacts using these operations, in order of preference:

| Operation | Helper | When to use |
|-----------|--------|-------------|
| **Create** | `render_template` | New file that doesn't exist. Always no-clobber. |
| **Append** | `inject_fragment` | Add block to end of file (requirements.txt, .env.example). Dedup by first line. |
| **Insert at section** | `inject_fragment_at` | Add block at a specific marker (`# -- dropwsl:<section> --`). Falls back to append. |
| **Replace line** | `sed -i` with `_sed_escape` | Modify a specific existing line (CMD, EXPOSE, import). |
| **Multi-line insert** | `make_temp` + `sed -i "$line r $tmp"` | Insert block at a line number. Never use `sed a\` or `\n`. |
| **Override** | `render_template` (no guard) or `mv` | Completely replace a file from a previous phase. Only for files the layer owns or that the phase contract allows. |

**Override rule:** a layer in a later phase may replace a file created by an earlier phase only when the replacement is a strict superset (e.g., `fastapi` replaces scaffold's `main.py` with a FastAPI-aware version). The override must be documented in the layer's header comment.

### Specialized injectors

| Helper | Target | Behavior |
|--------|--------|----------|
| `inject_vscode_extension` | `devcontainer.json` | Add extension ID to `extensions` array. Idempotent. |
| `inject_compose_service` | `compose.yaml` | Add service block. Creates skeleton if missing. |
| `inject_mcp_server` | `.vscode/mcp.json` | Add MCP server entry. Creates file if missing. |
| `ensure_env_example` | `.env.example` | Create with header if missing. No-clobber. |

### Python base specifics

- Multi-stage Docker: dev = bookworm, prod = slim-bookworm, non-root user.
- Venv at `/opt/venv` (fixed). Linter: Ruff. Tests: Pytest + pytest-cov.
- `CMD` in exec form: `CMD ["python", "main.py"]` (PID 1 receives SIGTERM).

## Security

Every base template, layer, and extension addition must consider security impact:

- **Dockerfile**: non-root user, no secrets in build args, minimal attack surface (slim images for prod).
- **Dependencies**: pin versions in `requirements.txt`. Layers that add dependencies must use the same pinning convention as the base template.
- **Environment variables**: secrets go in `.env` (gitignored), never in `.env.example` or committed files. `.env.example` contains only placeholder values.
- **Compose**: services use internal networks by default. Only expose ports explicitly needed for development.
- **Pre-commit hooks**: security layers (`gitleaks`, `semgrep`, `trivy`) are available as opt-in layers — consider recommending them when the project handles sensitive data.
- **Dev Container**: `postCreateCommand` runs as non-root. Docker socket mount is for development only — document this tradeoff in the project README.

## VS Code extensions

Every base template and layer that adds VS Code extensions must follow these rules:

- Only add extensions that are **market best practice** for the specific scenario (language, framework, infra tool).
- Use `inject_vscode_extension` to add to `devcontainer.json` — never edit the JSON manually.
- Never add deprecated extensions (e.g., `GitHub.copilot` — use `GitHub.copilot-chat` instead).
- Group extensions by purpose: language support, linting/formatting, testing, infrastructure, AI assistance.
- Each layer is responsible for its own extensions — a `postgres` layer adds database extensions, a `fastapi` layer adds API-related extensions. Never bundle unrelated extensions.

## Testing

### General rules

- Every code change (`.sh`, `.ps1`, `.cmd`) must include or update at least one corresponding test in `tests/`.
- Bash functions → bats tests. PowerShell functions → Pester tests.
- PS1 calling bash via `wsl.exe` → Pester with mocked `wsl.exe` + bats tests the bash function separately.
- Post-condition tests must cover **all** removals/changes, not a subset.
- Structural tests (parse, param list) are necessary but insufficient — every function needs happy path + error path tests at minimum.

### Test coverage by change type

Unit tests are always mandatory. Integration and E2E scale with the blast radius of the change:

| Change type | Unit | Integration | E2E |
|-------------|------|-------------|-----|
| Pure function / helper (`common.sh`, parser) | **required** | if changes public contract | — |
| Installer (`lib/core/*.sh`) | **required** | **required** | — |
| Layer (`lib/layers/`) | **required** | **required** (standalone + workspace) | if alters full stack |
| Scaffold / new / workspace (`lib/project/`) | **required** | **required** (standalone + workspace) | **required** |
| PowerShell wrapper (`.ps1`) | **required** (Pester) | — | — |
| Batch wrapper (`.cmd`) | **required** (Pester) | — | — |
| Full flow change (new command, new flag) | **required** | **required** | **required** |

### Standalone vs workspace test coverage

Any change to `lib/project/` or `lib/layers/` that affects path resolution, compose, `.env`, or devcontainer must be tested in **both modes**:

- **Standalone tests** validate single-project structure, direct compose ownership, and per-project git.
- **Workspace tests** validate multi-service structure, shared compose (copy-in/copy-back), merged `.env.example`, per-service devcontainer under `{workspace}/.devcontainer/{service}/`, and port auto-increment.
