#!/usr/bin/env bats
# tests/integration/combinations/test_combo_src_fastapi_azure_identity_foundry.bats
# Validates: src + fastapi + azure-identity + azure-ai-foundry combination.
# Both azure layers are self-contained (auth/ and foundry/ packages with router.py opt-in)
# and never modify main.py.

setup() {
  load '../../helpers/layer_test_helper'
  _common_setup
  PROJECT="$(setup_project_scaffold "testapp")"
  source_layer "${REPO_ROOT}/lib/layers/python/src.sh"
  source_layer "${REPO_ROOT}/lib/layers/python/fastapi.sh"
  source_layer "${REPO_ROOT}/lib/layers/python/azure-identity.sh"
  source_layer "${REPO_ROOT}/lib/layers/python/azure-ai-foundry.sh"
}

teardown() {
  _common_teardown
}

# ── Core combination ──────────────────────────────────────────────

@test "combo src+fastapi+identity+foundry: all modules present" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_ai_foundry "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -d "${PROJECT}/src/testapp/auth" ]
  assert [ -d "${PROJECT}/src/testapp/foundry" ]
  assert [ -f "${PROJECT}/src/testapp/foundry/client.py" ]
  assert [ -f "${PROJECT}/src/testapp/foundry/models.py" ]
  assert [ -f "${PROJECT}/src/testapp/foundry/connections.py" ]
}

@test "combo src+fastapi+identity+foundry: neither layer modifies main.py" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local before_hash; before_hash="$(md5sum "${PROJECT}/src/testapp/main.py" | cut -d' ' -f1)"
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_ai_foundry "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local after_hash; after_hash="$(md5sum "${PROJECT}/src/testapp/main.py" | cut -d' ' -f1)"
  assert_equal "$before_hash" "$after_hash"
}

@test "combo src+fastapi+identity+foundry: both routers expose their endpoints" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_ai_foundry "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq '/identity' "${PROJECT}/src/testapp/auth/router.py"
  grep -Fq '/foundry/status' "${PROJECT}/src/testapp/foundry/router.py"
  grep -Fq '/models' "${PROJECT}/src/testapp/foundry/router.py"
  grep -Fq '/connections' "${PROJECT}/src/testapp/foundry/router.py"
}

@test "combo src+fastapi+identity+foundry: foundry uses src prefix to import auth" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_ai_foundry "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "from testapp.auth.credential import" "${PROJECT}/src/testapp/foundry/client.py"
}

@test "combo src+fastapi+identity+foundry: both fixtures in conftest" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_ai_foundry "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq 'requires_azure' "${PROJECT}/tests/conftest.py"
  grep -Fq 'requires_foundry' "${PROJECT}/tests/conftest.py"
}

@test "combo src+fastapi+identity+foundry: README has both sections" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_ai_foundry "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq 'Authentication (Azure Identity)' "${PROJECT}/README.md"
  grep -Fq 'Azure AI Foundry' "${PROJECT}/README.md"
}

@test "combo src+fastapi+identity+foundry: requirements.txt has both deps" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_ai_foundry "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq 'azure-identity' "${PROJECT}/requirements.txt"
  grep -Fq 'azure-ai-projects' "${PROJECT}/requirements.txt"
}
