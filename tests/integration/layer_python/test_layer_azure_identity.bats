#!/usr/bin/env bats
# tests/integration/layer_python/test_layer_azure_identity.bats

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

@test "layer_azure_identity: creates src/{pkg}/auth/" {
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -d "${PROJECT}/src/testapp/auth" ]
  assert [ -f "${PROJECT}/src/testapp/auth/__init__.py" ]
  assert [ -f "${PROJECT}/src/testapp/auth/credential.py" ]
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

# ── post-create.sh ────────────────────────────────────────────────

@test "layer_azure_identity: post-create.sh has az login check" {
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq 'az account show' "${PROJECT}/.devcontainer/post-create.sh"
}

@test "layer_azure_identity: post-create.sh check is before Environment ready" {
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local check_line ready_line
  check_line="$(grep -n 'az account show' "${PROJECT}/.devcontainer/post-create.sh" | head -n1 | cut -d: -f1)"
  ready_line="$(grep -n 'Environment ready' "${PROJECT}/.devcontainer/post-create.sh" | head -n1 | cut -d: -f1)"
  assert [ -n "$check_line" ]
  assert [ -n "$ready_line" ]
  assert [ "$check_line" -lt "$ready_line" ]
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

# ── Standalone mode (no FastAPI) ──────────────────────────────────

@test "layer_azure_identity: standalone main.py has credential verification" {
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "credential_health" "${PROJECT}/src/testapp/main.py"
  grep -Fq "decode_token_claims" "${PROJECT}/src/testapp/main.py"
}

# ── With FastAPI ──────────────────────────────────────────────────

@test "layer_azure_identity: with FastAPI → health check injected" {
  source_layer "${REPO_ROOT}/lib/layers/python/fastapi.sh"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq 'health_status["azure_identity"]' "${PROJECT}/src/testapp/main.py"
}

@test "layer_azure_identity: with FastAPI → /api/identity route" {
  source_layer "${REPO_ROOT}/lib/layers/python/fastapi.sh"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq '/api/identity' "${PROJECT}/src/testapp/main.py"
}

@test "layer_azure_identity: with FastAPI → import credential_health" {
  source_layer "${REPO_ROOT}/lib/layers/python/fastapi.sh"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "from testapp.auth.credential import" "${PROJECT}/src/testapp/main.py"
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
  find "${PROJECT}/src/testapp/auth" -type f | sort | xargs md5sum > "$snap1" 2>/dev/null || true
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local snap2="${TEST_TEMP}/snap2"
  find "${PROJECT}/src/testapp/auth" -type f | sort | xargs md5sum > "$snap2" 2>/dev/null || true
  diff "$snap1" "$snap2"
}

@test "layer_azure_identity: idempotent with FastAPI" {
  source_layer "${REPO_ROOT}/lib/layers/python/fastapi.sh"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local count_before
  count_before=$(grep -c "credential_health" "${PROJECT}/src/testapp/main.py" || true)
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local count_afte
  count_after=$(grep -c "credential_health" "${PROJECT}/src/testapp/main.py" || true)
  assert [ "$count_before" -eq "$count_after" ]
}

# ── No CRLF ───────────────────────────────────────────────────────

@test "layer_azure_identity: no CRLF" {
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  ! grep -rP '\r' "${PROJECT}/src/testapp/auth/" 2>/dev/null
}

# ── Flat layout (no src/) ─────────────────────────────────────────

@test "layer_azure_identity: flat layout → auth/ at project root" {
  local flat_project="${TEST_TEMP}/flat_project"
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

  apply_layer_azure_identity "$flat_project" "testapp" "python" "${flat_project}/.devcontainer"
  assert [ -d "${flat_project}/auth" ]
  assert [ -f "${flat_project}/auth/credential.py" ]
  grep -Fq "credential_health" "${flat_project}/main.py"
}
