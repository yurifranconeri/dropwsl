#!/usr/bin/env bats
# tests/integration/combinations/test_combo_src_fastapi_azure_identity.bats
# Validates: src + fastapi + azure-identity combination.
# The azure-identity layer (infra) runs AFTER fastapi (framework) due to phase ordering,
# so it must correctly detect the async API and inject health check + /api/identity route.

setup() {
  load '../../helpers/layer_test_helper'
  _common_setup
  PROJECT="$(setup_project_scaffold "testapp")"
  source_layer "${REPO_ROOT}/lib/layers/python/src.sh"
  source_layer "${REPO_ROOT}/lib/layers/python/fastapi.sh"
  source_layer "${REPO_ROOT}/lib/layers/python/azure-identity.sh"
}

teardown() {
  _common_teardown
}

# ── Core combination ──────────────────────────────────────────────

@test "combo src+fastapi+identity: all modules present" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -d "${PROJECT}/src/testapp/auth" ]
  assert [ -f "${PROJECT}/src/testapp/auth/credential.py" ]
  assert [ -f "${PROJECT}/src/testapp/auth/__init__.py" ]
}

@test "combo src+fastapi+identity: health includes azure_identity" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq 'health_status["azure_identity"]' "${PROJECT}/src/testapp/main.py"
}

@test "combo src+fastapi+identity: /api/identity route present" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq '/api/identity' "${PROJECT}/src/testapp/main.py"
}

@test "combo src+fastapi+identity: import uses src layout prefix" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "from testapp.auth.credential import" "${PROJECT}/src/testapp/main.py"
}

@test "combo src+fastapi+identity: test_auth.py uses src layout import" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "import testapp.auth.credential as mod" "${PROJECT}/tests/unit/test_auth.py"
}

# ── With compose ──────────────────────────────────────────────────

@test "combo src+fastapi+compose+identity: no compose service for identity" {
  source_layer "${REPO_ROOT}/lib/layers/shared/compose.sh"
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_compose "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  # azure-identity is cloud auth — no compose service
  ! grep -Fq 'azure-identity:' "${PROJECT}/compose.yaml"
  ! grep -Fq 'azure_identity:' "${PROJECT}/compose.yaml"
}

# ── With postgres + redis ─────────────────────────────────────────

@test "combo src+fastapi+identity+postgres+redis: all health checks present" {
  source_layer "${REPO_ROOT}/lib/layers/shared/compose.sh"
  source_layer "${REPO_ROOT}/lib/layers/python/postgres.sh"
  source_layer "${REPO_ROOT}/lib/layers/python/redis.sh"
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_compose "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_postgres "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_redis "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local main_py="${PROJECT}/src/testapp/main.py"
  grep -Fq 'health_status["azure_identity"]' "$main_py"
  grep -Fq 'health_status["postgres"]' "$main_py"
  grep -Fq 'health_status["redis"]' "$main_py"
}

# ── devcontainer features ─────────────────────────────────────────

@test "combo src+fastapi+identity: devcontainer.json has azure-cli feature" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "azure-cli" "${PROJECT}/.devcontainer/devcontainer.json"
}

# ── Idempotency ───────────────────────────────────────────────────

@test "combo src+fastapi+identity: idempotent — no duplicate health checks" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local count_before
  count_before=$(grep -c 'azure_identity' "${PROJECT}/src/testapp/main.py" || true)
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local count_after
  count_after=$(grep -c 'azure_identity' "${PROJECT}/src/testapp/main.py" || true)
  assert [ "$count_before" -eq "$count_after" ]
}
