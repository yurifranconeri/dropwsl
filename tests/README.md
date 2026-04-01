# Tests

## Quick Start

```bash
# Run unit + integration (safe, no WSL/network needed)
./tests/run-tests.sh all

# Run only unit tests (~5s)
./tests/run-tests.sh unit

# Run only integration tests (~10s)
./tests/run-tests.sh integration

# Run PowerShell tests (Windows, outside WSL)
Invoke-Pester tests/pester/ -Output Detailed
```

## Test Pyramid

```
        ┌─────────┐
        │   E2E   │  ~70 tests — Docker builds, compose up, HTTP checks
        │         │            — requires Docker runtime, ~5min
        ├─────────┤
        │  Smoke  │  ~6 tests  — validate_all on a provisioned WSL
        ├─────────┤
        │ Integr. │  ~400 tests — layers, scaffold, workspace, inject_*
        │         │             — temp dir only, no network/sudo
        ├─────────┤
        │  Unit   │  ~230 tests — pure functions, parser, helpers
        │         │             — zero external I/O
        └─────────┘
        Install/Uninstall: ~75 tests (tool install stubs, clean paths)
        Pester: ~175 tests (PowerShell wrappers)
```

## Frameworks

| Language | Framework | Version |
|----------|-----------|---------|
| Bash | **bats-core** + bats-assert + bats-support + bats-file | 1.11+ |
| PowerShell | **Pester** | 5.x |

## Directory Structure

```
tests/
├── bats/                    # bats-core submodules
├── unit/                    # Pure functions, parser, helpers
├── integration/             # File generation, layers, scaffold
│   ├── layer_python/        # 1 file per Python layer (13 layers)
│   ├── layer_shared/        # 1 file per shared layer (13 layers)
│   └── combinations/        # Multi-layer interaction tests
├── install/                 # Tool installer tests (stubbed)
├── uninstall/               # clean-soft, purge, unregister tests
├── smoke/                   # Requires WSL with tools installed
├── e2e/                     # Docker runtime tests (compose up, HTTP)
├── pester/                  # PowerShell tests (Pester 5.x)
├── fixtures/                # Shared test data (YAML, JSON, TOML)
└── helpers/                 # Shared test helpers
    ├── test_helper.bash     # setup/teardown, source common.sh, stubs
    ├── mock_commands.bash   # Stubs: git, docker, code, sudo
    └── layer_test_helper.bash  # Scaffold + apply layer pattern
```

## Running Tests

### Entry Point: `tests/run-tests.sh`

```
Usage:  ./tests/run-tests.sh <level> [bats options]

Levels:
  unit             Pure functions, parser, helpers (~5s)
  integration      File generation, layers (~10s)
  smoke            Requires WSL with tools installed (~30s)
  e2e              Requires clean WSL (~5min)
  all              Unit + Integration (runs anywhere)
  full             All levels (unit + integration + smoke + e2e)
  pester           PowerShell tests via Pester (Windows only)

Bats options (passed through):
  --filter <regex>     Filter tests by name
  --filter-tags <tag>  Filter by tag
  --jobs <n>           Parallelism (default: nproc)
  --tap                TAP output format
  --verbose-run        Show each command executed
  --no-tempdir-cleanup Preserve temp dirs for debugging
```

### Common Scenarios

```bash
# Tests for a specific layer
./tests/run-tests.sh integration --filter "layer_fastapi"

# Only combination tests
./tests/run-tests.sh integration --filter "combo"

# Specific test by name
./tests/run-tests.sh unit --filter "version_gte: prefixo v misto"

# Debug: preserve temp dirs to inspect generated files
./tests/run-tests.sh integration --filter "layer_postgres" --no-tempdir-cleanup

# Debug: see each command bats executes
./tests/run-tests.sh unit --filter "config_parser" --verbose-run

# Parallel execution (powerful machine)
./tests/run-tests.sh all --jobs 4

# PowerShell — specific file
Invoke-Pester tests/pester/wsl-helpers.Tests.ps1 -Output Detailed
```

### When to Run What

| Situation | Command | Time |
|-----------|---------|------|
| Edited helper/parser in `common.sh` | `run-tests.sh unit` | <5s |
| Edited a layer | `run-tests.sh integration --filter "layer_<name>"` | <3s |
| Edited `inject_*` in `common.sh` | `run-tests.sh integration --filter "inject"` | <3s |
| Edited scaffold/new/workspace | `run-tests.sh integration --filter "scaffold\|new\|workspace"` | <5s |
| Before any commit | `run-tests.sh all` | ~12s |
| Edited `.ps1` files | `run-tests.sh pester` | <5s |
| After provisioning WSL | `run-tests.sh smoke` | ~30s |
| Pre-release | `run-tests.sh full` | ~6min |

## Writing Tests

### Rule: Every Code Change Needs a Test

| Change type | Required test | Example |
|-------------|---------------|---------|
| New function | Unit test | Added `parse_foo()` → test inputs/outputs |
| Bug fix | Test that reproduces the bug | Distro fallback → test empty `WSL_DISTRO_NAME` |
| Modified function | Test for the new behavior | Changed `load_config()` → test new field parsing |
| New layer | Full integration test | Added `celery.sh` → create `test_layer_celery.bats` |
| Modified layer | Test for the changed scenario | Changed Dockerfile injection → test Dockerfile content |
| PowerShell change | Pester test | Changed `Sync-WslConfig` → test new case |
| Refactor (no behavior change) | Existing tests must pass | Run `run-tests.sh all` |

**Exceptions** (no new test needed): docs-only changes, config-only changes (no new field), refactors with zero behavior change, core installers (covered by smoke/E2E).

### Cross-cutting Checks for Layer Tests

Every layer test should include:

| Check | How | Why |
|-------|-----|-----|
| Valid JSON | `python3 -m json.tool < file.json` | Corrupted devcontainer.json = broken project |
| Dockerfile parseable | `grep` for FROM/RUN/COPY/CMD/EXPOSE | Layers inject directives |
| No `\r` | `grep -cP '\r' file` = 0 | CRLF breaks bash |
| Idempotent | Apply layer 2x, diff before vs after | `diff <(cat after-1st) <(cat after-2nd)` |

### Test Helpers

- **`test_helper.bash`** — Loaded by every `.bats`. Sources `common.sh`, creates temp dirs, provides stubs.
- **`mock_commands.bash`** — Stubs for `has_cmd`, `sudo`, `git`, `code`, `run_quiet`. Call `activate_mocks` to enable.
- **`layer_test_helper.bash`** — `setup_project_scaffold()` creates a full Python scaffold in `$TEST_TEMP/project`.

## Coverage

| Level | Tests | Scope |
|-------|-------|-------|
| Unit | ~230 | Pure functions, parser, helpers |
| Integration | ~400 | Layers (26 files), scaffold, workspace, inject_* |
| Combinations | ~110 | Multi-layer interaction scenarios |
| Install | ~48 | Tool installer stubs |
| Uninstall | ~28 | clean-soft, purge, unregister |
| Smoke | ~6 | validate_all on provisioned WSL |
| E2E | ~71 | Docker builds, compose up, HTTP health checks |
| Pester | ~176 | PowerShell wrappers (.ps1 + .cmd) |
| **Total** | **~960** | |
