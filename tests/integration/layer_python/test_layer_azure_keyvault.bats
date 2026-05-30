#!/usr/bin/env bats
# tests/integration/layer_python/test_layer_azure_keyvault.bats

setup() {
  load '../../helpers/layer_test_helper'
  _common_setup
  PROJECT="$(setup_project_scaffold "testapp")"
  source_layer "${REPO_ROOT}/lib/layers/python/src.sh"
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  source_layer "${REPO_ROOT}/lib/layers/python/azure-identity.sh"
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  source_layer "${REPO_ROOT}/lib/layers/python/azure-keyvault.sh"
}

teardown() {
  _common_teardown
}

# ── Core artifacts ─────────────────────────────────────────────────

@test "layer_azure_keyvault: creates src/{pkg}/keyvault/ with all files" {
  apply_layer_azure_keyvault "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -d "${PROJECT}/src/testapp/keyvault" ]
  assert [ -f "${PROJECT}/src/testapp/keyvault/__init__.py" ]
  assert [ -f "${PROJECT}/src/testapp/keyvault/__main__.py" ]
  assert [ -f "${PROJECT}/src/testapp/keyvault/client.py" ]
  assert [ -f "${PROJECT}/src/testapp/keyvault/secrets.py" ]
  assert [ -f "${PROJECT}/src/testapp/keyvault/router.py" ]
  assert [ -f "${PROJECT}/src/testapp/keyvault/ui.py" ]
}

@test "layer_azure_keyvault: requirements.txt contains azure-keyvault-secrets" {
  apply_layer_azure_keyvault "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "azure-keyvault-secrets" "${PROJECT}/requirements.txt"
}

@test "layer_azure_keyvault: .env.example contains AZURE_KEYVAULT_URL" {
  apply_layer_azure_keyvault "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "AZURE_KEYVAULT_URL" "${PROJECT}/.env.example"
}

@test "layer_azure_keyvault: test file created" {
  apply_layer_azure_keyvault "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -f "${PROJECT}/tests/unit/test_keyvault.py" ]
  grep -Fq "test_metadata_only_by_default" "${PROJECT}/tests/unit/test_keyvault.py"
  grep -Fq "test_invalid_name_raises_value_error" "${PROJECT}/tests/unit/test_keyvault.py"
}

# ── Self-containment principle ────────────────────────────────────

@test "layer_azure_keyvault: does NOT modify main.py" {
  local before_hash; before_hash="$(md5sum "${PROJECT}/src/testapp/main.py" | cut -d' ' -f1)"
  apply_layer_azure_keyvault "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local after_hash; after_hash="$(md5sum "${PROJECT}/src/testapp/main.py" | cut -d' ' -f1)"
  assert_equal "$before_hash" "$after_hash"
}

@test "layer_azure_keyvault: __main__.py is runnable form" {
  apply_layer_azure_keyvault "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq 'if __name__ == "__main__"' "${PROJECT}/src/testapp/keyvault/__main__.py"
  grep -Fq 'sys.exit(main())' "${PROJECT}/src/testapp/keyvault/__main__.py"
}

# ── Import paths (src layout) ─────────────────────────────────────

@test "layer_azure_keyvault: client.py uses src layout prefix for auth import" {
  apply_layer_azure_keyvault "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "from testapp.auth.credential import" "${PROJECT}/src/testapp/keyvault/client.py"
}

@test "layer_azure_keyvault: secrets.py uses relative import" {
  apply_layer_azure_keyvault "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "from .client import" "${PROJECT}/src/testapp/keyvault/secrets.py"
}

@test "layer_azure_keyvault: __init__.py uses relative imports (works in src and flat)" {
  apply_layer_azure_keyvault "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "from .client import" "${PROJECT}/src/testapp/keyvault/__init__.py"
  grep -Fq "from .secrets import" "${PROJECT}/src/testapp/keyvault/__init__.py"
}

@test "layer_azure_keyvault: test file uses src layout import" {
  apply_layer_azure_keyvault "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "import testapp.keyvault.client as client_mod" "${PROJECT}/tests/unit/test_keyvault.py"
  grep -Fq "import testapp.keyvault.secrets as secrets_mod" "${PROJECT}/tests/unit/test_keyvault.py"
}

# ── Opt-in integrations ───────────────────────────────────────────

@test "layer_azure_keyvault: router.py exports APIRouter" {
  apply_layer_azure_keyvault "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "router = APIRouter" "${PROJECT}/src/testapp/keyvault/router.py"
  grep -Fq "/status" "${PROJECT}/src/testapp/keyvault/router.py"
  grep -Fq "/secrets" "${PROJECT}/src/testapp/keyvault/router.py"
}

@test "layer_azure_keyvault: ui.py exports render_keyvault_panel" {
  apply_layer_azure_keyvault "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "def render_keyvault_panel" "${PROJECT}/src/testapp/keyvault/ui.py"
}

# ── Security ──────────────────────────────────────────────────────

@test "layer_azure_keyvault: router never returns secret values" {
  apply_layer_azure_keyvault "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  # router.py must call get_secret with reveal=False (or default)
  ! grep -Fq "reveal=True" "${PROJECT}/src/testapp/keyvault/router.py"
}

@test "layer_azure_keyvault: env.example value is empty placeholder" {
  apply_layer_azure_keyvault "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "AZURE_KEYVAULT_URL=" "${PROJECT}/.env.example"
  ! grep -Eq '^AZURE_KEYVAULT_URL=.+' "${PROJECT}/.env.example"
}

# ── README ────────────────────────────────────────────────────────

@test "layer_azure_keyvault: README contains Azure Key Vault section" {
  apply_layer_azure_keyvault "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq 'Azure Key Vault' "${PROJECT}/README.md"
}

@test "layer_azure_keyvault: README has keyvault/ in structure tree" {
  apply_layer_azure_keyvault "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq 'keyvault/' "${PROJECT}/README.md"
}

@test "layer_azure_keyvault: README integration snippet uses src prefix" {
  apply_layer_azure_keyvault "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "from testapp.keyvault.router import" "${PROJECT}/README.md"
  grep -Fq "from testapp.keyvault.ui import" "${PROJECT}/README.md"
}

# ── Idempotency ───────────────────────────────────────────────────

@test "layer_azure_keyvault: idempotent" {
  apply_layer_azure_keyvault "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local snap1="${TEST_TEMP}/snap1"
  mkdir -p "$snap1"
  cp -a "$PROJECT" "$snap1/project"

  apply_layer_azure_keyvault "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  diff -rq "$snap1/project" "$PROJECT"
}

# ── Metadata ──────────────────────────────────────────────────────

@test "layer_azure_keyvault: phase is infra" {
  local phase
  phase="$(grep -m1 '^_LAYER_PHASE=' "${REPO_ROOT}/lib/layers/python/azure-keyvault.sh" | cut -d'"' -f2)"
  assert_equal "$phase" "infra"
}

@test "layer_azure_keyvault: requires azure-identity" {
  local requires
  requires="$(grep -m1 '^_LAYER_REQUIRES=' "${REPO_ROOT}/lib/layers/python/azure-keyvault.sh" | cut -d'"' -f2)"
  assert_equal "$requires" "azure-identity"
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

  apply_layer_azure_identity "$flat_project" "testapp" "python" "${flat_project}/.devcontainer" >&2
  echo "$flat_project"
}

@test "layer_azure_keyvault: flat layout → keyvault/ at project root" {
  local flat_project; flat_project="$(_setup_flat_project)"
  apply_layer_azure_keyvault "$flat_project" "testapp" "python" "${flat_project}/.devcontainer"
  assert [ -d "${flat_project}/keyvault" ]
  assert [ -f "${flat_project}/keyvault/__init__.py" ]
  assert [ -f "${flat_project}/keyvault/__main__.py" ]
  assert [ -f "${flat_project}/keyvault/client.py" ]
  assert [ -f "${flat_project}/keyvault/secrets.py" ]
  assert [ -f "${flat_project}/keyvault/router.py" ]
  assert [ -f "${flat_project}/keyvault/ui.py" ]
}

@test "layer_azure_keyvault: flat layout → no src prefix in imports" {
  local flat_project; flat_project="$(_setup_flat_project)"
  apply_layer_azure_keyvault "$flat_project" "testapp" "python" "${flat_project}/.devcontainer"
  grep -Fq "from auth.credential import" "${flat_project}/keyvault/client.py"
  grep -Fq "from .client import" "${flat_project}/keyvault/secrets.py"
}

@test "layer_azure_keyvault: flat layout → README integration snippet uses bare import" {
  local flat_project; flat_project="$(_setup_flat_project)"
  apply_layer_azure_keyvault "$flat_project" "testapp" "python" "${flat_project}/.devcontainer"
  grep -Fq "from keyvault.router import" "${flat_project}/README.md"
  grep -Fq "from keyvault.ui import" "${flat_project}/README.md"
  ! grep -Fq "from testapp.keyvault" "${flat_project}/README.md"
}

@test "layer_azure_keyvault: flat layout → does NOT modify main.py" {
  local flat_project; flat_project="$(_setup_flat_project)"
  local before_hash; before_hash="$(md5sum "${flat_project}/main.py" | cut -d' ' -f1)"
  apply_layer_azure_keyvault "$flat_project" "testapp" "python" "${flat_project}/.devcontainer"
  local after_hash; after_hash="$(md5sum "${flat_project}/main.py" | cut -d' ' -f1)"
  assert_equal "$before_hash" "$after_hash"
}
