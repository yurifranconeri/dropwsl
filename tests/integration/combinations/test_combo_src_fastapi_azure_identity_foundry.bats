#!/usr/bin/env bats
# tests/integration/combinations/test_combo_src_fastapi_azure_identity_foundry.bats
# Validates: src + fastapi + azure-identity + azure-ai-foundry combination.
# Both azure layers (infra phase) run AFTER fastapi (framework),
# so they must correctly detect the async API and inject health checks + routes.

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

@test "combo src+fastapi+identity+foundry: both health checks present" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_ai_foundry "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq 'health_status["azure_identity"]' "${PROJECT}/src/testapp/main.py"
  grep -Fq 'health_status["azure_foundry"]' "${PROJECT}/src/testapp/main.py"
}

@test "combo src+fastapi+identity+foundry: both routes present" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_ai_foundry "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq '/api/identity' "${PROJECT}/src/testapp/main.py"
  grep -Fq '/api/foundry/status' "${PROJECT}/src/testapp/main.py"
  grep -Fq '/api/models' "${PROJECT}/src/testapp/main.py"
  grep -Fq '/api/connections' "${PROJECT}/src/testapp/main.py"
}

@test "combo src+fastapi+identity+foundry: import uses src layout prefix" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_ai_foundry "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "from testapp.auth.credential import" "${PROJECT}/src/testapp/main.py"
  grep -Fq "from testapp.foundry.client import" "${PROJECT}/src/testapp/main.py"
  grep -Fq "from testapp.foundry.models import" "${PROJECT}/src/testapp/main.py"
  grep -Fq "from testapp.foundry.connections import" "${PROJECT}/src/testapp/main.py"
}

@test "combo src+fastapi+identity+foundry: foundry client.py uses src prefix for auth" {
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
