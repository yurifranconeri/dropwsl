#!/usr/bin/env bats
# tests/integration/combinations/test_combo_src_fastapi_azure_identity.bats
# Validates: src + fastapi + azure-identity combination.
# The azure-identity layer is self-contained (auth/ package with router.py opt-in)
# and never modifies main.py. The dev mounts the router via app.include_router.

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

@test "combo src+fastapi+identity: identity does NOT modify FastAPI main.py" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local before_hash; before_hash="$(md5sum "${PROJECT}/src/testapp/main.py" | cut -d' ' -f1)"
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local after_hash; after_hash="$(md5sum "${PROJECT}/src/testapp/main.py" | cut -d' ' -f1)"
  assert_equal "$before_hash" "$after_hash"
}

@test "combo src+fastapi+identity: /api/identity available via opt-in router" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq '/identity' "${PROJECT}/src/testapp/auth/router.py"
  grep -Fq 'router = APIRouter' "${PROJECT}/src/testapp/auth/router.py"
}

@test "combo src+fastapi+identity: README documents src-layout integration" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "from testapp.auth.router import" "${PROJECT}/README.md"
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

@test "combo src+fastapi+identity+postgres+redis: postgres+redis health checks present, identity stays opt-in" {
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
  # postgres and redis still mutate main.py (legacy debt — separate cleanup)
  grep -Fq 'health_status["postgres"]' "$main_py"
  grep -Fq 'health_status["redis"]' "$main_py"
  # identity follows the self-containment principle — auth/ package only
  assert [ -f "${PROJECT}/src/testapp/auth/router.py" ]
  ! grep -Fq 'health_status["azure_identity"]' "$main_py"
}

# ── devcontainer features ─────────────────────────────────────────

@test "combo src+fastapi+identity: devcontainer.json has azure-cli feature" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "azure-cli" "${PROJECT}/.devcontainer/devcontainer.json"
}

# ── Idempotency ───────────────────────────────────────────────────

@test "combo src+fastapi+identity: idempotent — auth/ package unchanged on re-apply" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local before_hash; before_hash="$(find "${PROJECT}/src/testapp/auth" -type f -exec md5sum {} + | sort | md5sum)"
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local after_hash; after_hash="$(find "${PROJECT}/src/testapp/auth" -type f -exec md5sum {} + | sort | md5sum)"
  assert_equal "$before_hash" "$after_hash"
}
