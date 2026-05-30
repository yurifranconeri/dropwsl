#!/usr/bin/env bats
# tests/integration/layer_python/test_layer_pydantic_settings.bats

setup() {
  load '../../helpers/layer_test_helper'
  _common_setup
  PROJECT="$(setup_project_scaffold "testapp")"
  # Use src layout as primary scenario.
  source_layer "${REPO_ROOT}/lib/layers/python/src.sh"
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  source_layer "${REPO_ROOT}/lib/layers/python/pydantic-settings.sh"
}

teardown() {
  _common_teardown
}

# ── Core artifacts ────────────────────────────────────────────────

@test "layer_pydantic_settings: creates config/ package" {
  apply_layer_pydantic_settings "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -d "${PROJECT}/src/testapp/config" ]
  assert [ -f "${PROJECT}/src/testapp/config/__init__.py" ]
  assert [ -f "${PROJECT}/src/testapp/config/__main__.py" ]
  assert [ -f "${PROJECT}/src/testapp/config/settings.py" ]
  assert [ -f "${PROJECT}/src/testapp/config/cli.py" ]
}

@test "layer_pydantic_settings: requirements.txt has pydantic-settings" {
  apply_layer_pydantic_settings "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "pydantic-settings" "${PROJECT}/requirements.txt"
}

@test "layer_pydantic_settings: .env.example has APP_NAME, APP_ENV, LOG_LEVEL" {
  apply_layer_pydantic_settings "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "APP_NAME=" "${PROJECT}/.env.example"
  grep -Fq "APP_ENV=" "${PROJECT}/.env.example"
  grep -Fq "LOG_LEVEL=" "${PROJECT}/.env.example"
}

@test "layer_pydantic_settings: .env.example uses project name as APP_NAME default" {
  apply_layer_pydantic_settings "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "APP_NAME=testapp" "${PROJECT}/.env.example"
}

@test "layer_pydantic_settings: README has Configuration section" {
  apply_layer_pydantic_settings "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "## Configuration" "${PROJECT}/README.md"
}

@test "layer_pydantic_settings: unit test file created" {
  apply_layer_pydantic_settings "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -f "${PROJECT}/tests/unit/test_config.py" ]
}

@test "layer_pydantic_settings: unit test imports rewritten for src layout" {
  apply_layer_pydantic_settings "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "from testapp.config import" "${PROJECT}/tests/unit/test_config.py"
  ! grep -Eq "^from config import" "${PROJECT}/tests/unit/test_config.py"
}

# ── Placeholder substitution ──────────────────────────────────────

@test "layer_pydantic_settings: PKG_PREFIX substituted in settings.py docstring" {
  apply_layer_pydantic_settings "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "from testapp.config import" "${PROJECT}/src/testapp/config/settings.py"
  ! grep -Fq '{{PKG_PREFIX}}' "${PROJECT}/src/testapp/config/settings.py"
}

@test "layer_pydantic_settings: PROJECT_NAME substituted in settings.py default" {
  apply_layer_pydantic_settings "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq 'default="testapp"' "${PROJECT}/src/testapp/config/settings.py"
  ! grep -Fq '{{PROJECT_NAME}}' "${PROJECT}/src/testapp/config/settings.py"
}

@test "layer_pydantic_settings: PKG_PREFIX substituted in cli.py PROG" {
  apply_layer_pydantic_settings "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq 'python -m testapp.config' "${PROJECT}/src/testapp/config/cli.py"
  ! grep -Fq '{{PKG_PREFIX}}' "${PROJECT}/src/testapp/config/cli.py"
}

@test "layer_pydantic_settings: PKG_PREFIX substituted in __init__.py and __main__.py" {
  apply_layer_pydantic_settings "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  ! grep -Fq '{{PKG_PREFIX}}' "${PROJECT}/src/testapp/config/__init__.py"
  ! grep -Fq '{{PKG_PREFIX}}' "${PROJECT}/src/testapp/config/__main__.py"
}

# ── Does NOT modify user's main.py / compose / devcontainer ──────

@test "layer_pydantic_settings: does NOT modify main.py" {
  local before
  before="$(sha256sum "${PROJECT}/src/testapp/main.py" | cut -d' ' -f1)"
  apply_layer_pydantic_settings "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local after
  after="$(sha256sum "${PROJECT}/src/testapp/main.py" | cut -d' ' -f1)"
  assert_equal "$before" "$after"
}

@test "layer_pydantic_settings: does NOT modify compose.yaml when present" {
  [[ -f "${PROJECT}/compose.yaml" ]] || skip "compose.yaml not present"
  local before
  before="$(sha256sum "${PROJECT}/compose.yaml" | cut -d' ' -f1)"
  apply_layer_pydantic_settings "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local after
  after="$(sha256sum "${PROJECT}/compose.yaml" | cut -d' ' -f1)"
  assert_equal "$before" "$after"
}

@test "layer_pydantic_settings: does NOT modify devcontainer.json" {
  local before
  before="$(sha256sum "${PROJECT}/.devcontainer/devcontainer.json" | cut -d' ' -f1)"
  apply_layer_pydantic_settings "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local after
  after="$(sha256sum "${PROJECT}/.devcontainer/devcontainer.json" | cut -d' ' -f1)"
  assert_equal "$before" "$after"
}

# ── Idempotency ───────────────────────────────────────────────────

@test "layer_pydantic_settings: idempotent (no diff on second apply)" {
  apply_layer_pydantic_settings "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local snap="${TEST_TEMP}/snap"
  mkdir -p "$snap"
  cp -a "$PROJECT" "$snap/project"

  apply_layer_pydantic_settings "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  diff -rq "$snap/project" "$PROJECT"
}

@test "layer_pydantic_settings: requirements not duplicated on re-apply" {
  apply_layer_pydantic_settings "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_pydantic_settings "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  # Anchor to the dep line itself -- the guard comment also contains the
  # substring "pydantic-settings", so an unanchored grep would always count 2.
  local count
  count="$(grep -cE '^pydantic-settings>=' "${PROJECT}/requirements.txt")"
  assert_equal "$count" "1"
}

@test "layer_pydantic_settings: env.example not duplicated on re-apply" {
  apply_layer_pydantic_settings "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_pydantic_settings "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local count
  count="$(grep -cF 'APP_ENV=' "${PROJECT}/.env.example")"
  assert_equal "$count" "1"
}

# ── Metadata ──────────────────────────────────────────────────────

@test "layer_pydantic_settings: phase is tooling" {
  local phase
  phase="$(grep -m1 '^_LAYER_PHASE=' "${REPO_ROOT}/lib/layers/python/pydantic-settings.sh" | cut -d'"' -f2)"
  assert_equal "$phase" "tooling"
}

@test "layer_pydantic_settings: requires nothing" {
  local requires
  requires="$(grep -m1 '^_LAYER_REQUIRES=' "${REPO_ROOT}/lib/layers/python/pydantic-settings.sh" | cut -d'"' -f2)"
  assert_equal "$requires" ""
}

# ── Python syntax (rendered) ──────────────────────────────────────

@test "layer_pydantic_settings: all generated .py files compile" {
  apply_layer_pydantic_settings "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  command -v python3 >/dev/null || skip "python3 not available"
  for f in "${PROJECT}/src/testapp/config/"*.py "${PROJECT}/tests/unit/test_config.py"; do
    python3 -m py_compile "$f"
  done
}

# ── Typing: fixture must declare Iterator[None] to satisfy mypy strict ──

@test "layer_pydantic_settings: test_config _clear_settings_cache returns Iterator[None]" {
  apply_layer_pydantic_settings "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq 'from collections.abc import Iterator' "${PROJECT}/tests/unit/test_config.py"
  grep -Eq '_clear_settings_cache\(.*\) -> Iterator\[None\]' "${PROJECT}/tests/unit/test_config.py"
}

# ── Flat layout ───────────────────────────────────────────────────

_setup_flat_project() {
  local flat_project="${TEST_TEMP}/flat_project_$$"
  mkdir -p "${flat_project}/tests"
  local tpl_dir="${REPO_ROOT}/templates/devcontainer/python"
  cp -r "${tpl_dir}/.devcontainer" "${flat_project}/.devcontainer"
  cp "${tpl_dir}/Dockerfile" "${flat_project}/"
  cp "${tpl_dir}/pyproject.toml" "${flat_project}/"
  cp "${tpl_dir}/main.py" "${flat_project}/"
  cp "${tpl_dir}/requirements.txt" "${flat_project}/"
  cp "${tpl_dir}/requirements-dev.txt" "${flat_project}/"
  [[ -f "${tpl_dir}/README.md" ]] && cp "${tpl_dir}/README.md" "${flat_project}/"
  [[ -d "${tpl_dir}/tests" ]] && cp "${tpl_dir}/tests/"* "${flat_project}/tests/" 2>/dev/null || true
  for f in "${tpl_dir}"/.[!.]*; do
    [[ -e "$f" ]] && [[ ! -d "$f" ]] && cp "$f" "${flat_project}/"
  done
  echo "$flat_project"
}

@test "layer_pydantic_settings: flat layout → config/ at project root" {
  local flat_project; flat_project="$(_setup_flat_project)"
  apply_layer_pydantic_settings "$flat_project" "testapp" "python" "${flat_project}/.devcontainer"
  assert [ -d "${flat_project}/config" ]
  assert [ -f "${flat_project}/config/settings.py" ]
}

@test "layer_pydantic_settings: flat layout → unit test uses bare import" {
  local flat_project; flat_project="$(_setup_flat_project)"
  apply_layer_pydantic_settings "$flat_project" "testapp" "python" "${flat_project}/.devcontainer"
  grep -Fq "from config import" "${flat_project}/tests/unit/test_config.py"
  ! grep -Fq "from testapp.config" "${flat_project}/tests/unit/test_config.py"
}

@test "layer_pydantic_settings: flat layout → PKG_PREFIX strips cleanly in __init__" {
  local flat_project; flat_project="$(_setup_flat_project)"
  apply_layer_pydantic_settings "$flat_project" "testapp" "python" "${flat_project}/.devcontainer"
  grep -Fq "from config.settings import" "${flat_project}/config/__init__.py"
}

# ── Co-existence ──────────────────────────────────────────────────

@test "layer_pydantic_settings: coexists with streamlit-auth (config/ and users/ both present)" {
  source_layer "${REPO_ROOT}/lib/layers/python/streamlit.sh"
  apply_layer_streamlit "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  source_layer "${REPO_ROOT}/lib/layers/python/streamlit-auth.sh"
  apply_layer_streamlit_auth "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_pydantic_settings "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -d "${PROJECT}/src/testapp/users" ]
  assert [ -d "${PROJECT}/src/testapp/config" ]
}

@test "layer_pydantic_settings: coexists with fastapi" {
  source_layer "${REPO_ROOT}/lib/layers/python/fastapi.sh"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_pydantic_settings "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -d "${PROJECT}/src/testapp/config" ]
  # FastAPI's main.py must remain untouched
  grep -Fq "FastAPI" "${PROJECT}/src/testapp/main.py"
}

@test "layer_pydantic_settings: coexists with uv (requirements.txt still gets pydantic-settings)" {
  source_layer "${REPO_ROOT}/lib/layers/python/uv.sh"
  apply_layer_uv "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_pydantic_settings "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "pydantic-settings" "${PROJECT}/requirements.txt"
  assert [ -d "${PROJECT}/src/testapp/config" ]
}
