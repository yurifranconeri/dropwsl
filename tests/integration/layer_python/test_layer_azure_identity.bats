#!/usr/bin/env bats
# tests/integration/layer_python/test_layer_azure_identity.bats
# Validates the self-contained auth/ package — never modifies main.py.

setup() {
  load '../../helpers/layer_test_helper'
  _common_setup
  PROJECT="$(setup_project_scaffold "testapp")"
  source_layer "${REPO_ROOT}/lib/layers/python/src.sh"
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  source_layer "${REPO_ROOT}/lib/layers/python/azure-identity.sh"
}

teardown() {
  _common_teardown
}

# ── Core artifacts ─────────────────────────────────────────────────

@test "layer_azure_identity: creates src/{pkg}/auth/ with all files" {
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -d "${PROJECT}/src/testapp/auth" ]
  assert [ -f "${PROJECT}/src/testapp/auth/__init__.py" ]
  assert [ -f "${PROJECT}/src/testapp/auth/__main__.py" ]
  assert [ -f "${PROJECT}/src/testapp/auth/credential.py" ]
  assert [ -f "${PROJECT}/src/testapp/auth/router.py" ]
  assert [ -f "${PROJECT}/src/testapp/auth/ui.py" ]
}

@test "layer_azure_identity: requirements.txt contains azure-identity" {
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "azure-identity" "${PROJECT}/requirements.txt"
}

@test "layer_azure_identity: .env.example contains AZURE_TENANT_ID" {
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "AZURE_TENANT_ID" "${PROJECT}/.env.example"
}

@test "layer_azure_identity: test file created" {
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -f "${PROJECT}/tests/unit/test_auth.py" ]
  grep -Fq "test_returns_instance" "${PROJECT}/tests/unit/test_auth.py"
}

# ── Self-containment principle ────────────────────────────────────

@test "layer_azure_identity: does NOT modify main.py" {
  local before_hash; before_hash="$(md5sum "${PROJECT}/src/testapp/main.py" | cut -d' ' -f1)"
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local after_hash; after_hash="$(md5sum "${PROJECT}/src/testapp/main.py" | cut -d' ' -f1)"
  assert_equal "$before_hash" "$after_hash"
}

@test "layer_azure_identity: does NOT modify main.py even when FastAPI is present" {
  source_layer "${REPO_ROOT}/lib/layers/python/fastapi.sh"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local before_hash; before_hash="$(md5sum "${PROJECT}/src/testapp/main.py" | cut -d' ' -f1)"
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local after_hash; after_hash="$(md5sum "${PROJECT}/src/testapp/main.py" | cut -d' ' -f1)"
  assert_equal "$before_hash" "$after_hash"
}

@test "layer_azure_identity: __main__.py is runnable form" {
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq 'if __name__ == "__main__"' "${PROJECT}/src/testapp/auth/__main__.py"
  grep -Fq 'sys.exit(main())' "${PROJECT}/src/testapp/auth/__main__.py"
}

@test "layer_azure_identity: router.py exports APIRouter with /identity" {
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "router = APIRouter" "${PROJECT}/src/testapp/auth/router.py"
  grep -Fq "/identity" "${PROJECT}/src/testapp/auth/router.py"
}

@test "layer_azure_identity: ui.py exports render_identity_panel" {
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "def render_identity_panel" "${PROJECT}/src/testapp/auth/ui.py"
}

# ── post-create.sh ────────────────────────────────────────────────

@test "layer_azure_identity: post-create.sh has az login check" {
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq 'az account show' "${PROJECT}/.devcontainer/post-create.sh"
}

# ── conftest fixture ──────────────────────────────────────────────

@test "layer_azure_identity: conftest has requires_azure fixture" {
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq 'requires_azure' "${PROJECT}/tests/conftest.py"
}

# ── devcontainer feature ──────────────────────────────────────────

@test "layer_azure_identity: devcontainer.json has azure-cli feature" {
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "azure-cli" "${PROJECT}/.devcontainer/devcontainer.json"
}

# ── Import paths (src layout) ─────────────────────────────────────

@test "layer_azure_identity: README integration snippets use src prefix" {
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "from testapp.auth.router import" "${PROJECT}/README.md"
  grep -Fq "from testapp.auth.ui import" "${PROJECT}/README.md"
  grep -Fq "python -m testapp.auth" "${PROJECT}/README.md"
}

@test "layer_azure_identity: test file uses src layout import" {
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "import testapp.auth.credential as mod" "${PROJECT}/tests/unit/test_auth.py"
}

# ── README ────────────────────────────────────────────────────────

@test "layer_azure_identity: README contains Authentication section" {
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq 'Authentication (Azure Identity)' "${PROJECT}/README.md"
}

@test "layer_azure_identity: README has auth/ in structure tree" {
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq 'auth/' "${PROJECT}/README.md"
}

# ── Idempotency ───────────────────────────────────────────────────

@test "layer_azure_identity: idempotent" {
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local snap1="${TEST_TEMP}/snap1"
  mkdir -p "$snap1"
  cp -a "$PROJECT" "$snap1/project"
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  diff -rq "$snap1/project" "$PROJECT"
}

# ── No CRLF ───────────────────────────────────────────────────────

@test "layer_azure_identity: no CRLF in auth/" {
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  ! grep -rP '\r' "${PROJECT}/src/testapp/auth/" 2>/dev/null
}

# ── Flat layout (no src/) ─────────────────────────────────────────

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

@test "layer_azure_identity: flat layout → auth/ at project root" {
  local flat_project; flat_project="$(_setup_flat_project)"
  apply_layer_azure_identity "$flat_project" "testapp" "python" "${flat_project}/.devcontainer"
  assert [ -d "${flat_project}/auth" ]
  assert [ -f "${flat_project}/auth/__init__.py" ]
  assert [ -f "${flat_project}/auth/__main__.py" ]
  assert [ -f "${flat_project}/auth/credential.py" ]
  assert [ -f "${flat_project}/auth/router.py" ]
  assert [ -f "${flat_project}/auth/ui.py" ]
}

@test "layer_azure_identity: flat layout → README uses bare import" {
  local flat_project; flat_project="$(_setup_flat_project)"
  apply_layer_azure_identity "$flat_project" "testapp" "python" "${flat_project}/.devcontainer"
  grep -Fq "from auth.router import" "${flat_project}/README.md"
  grep -Fq "from auth.ui import" "${flat_project}/README.md"
  ! grep -Fq "from testapp.auth" "${flat_project}/README.md"
}

@test "layer_azure_identity: flat layout → does NOT modify main.py" {
  local flat_project; flat_project="$(_setup_flat_project)"
  local before_hash; before_hash="$(md5sum "${flat_project}/main.py" | cut -d' ' -f1)"
  apply_layer_azure_identity "$flat_project" "testapp" "python" "${flat_project}/.devcontainer"
  local after_hash; after_hash="$(md5sum "${flat_project}/main.py" | cut -d' ' -f1)"
  assert_equal "$before_hash" "$after_hash"
}

# ── Metadata ──────────────────────────────────────────────────────

@test "layer_azure_identity: phase is infra" {
  local phase
  phase="$(grep -m1 '^_LAYER_PHASE=' "${REPO_ROOT}/lib/layers/python/azure-identity.sh" | cut -d'"' -f2)"
  assert_equal "$phase" "infra"
}
