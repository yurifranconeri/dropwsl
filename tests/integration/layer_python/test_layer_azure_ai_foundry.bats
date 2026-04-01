#!/usr/bin/env bats
# tests/integration/layer_python/test_layer_azure_ai_foundry.bats

setup() {
  load '../../helpers/layer_test_helper'
  _common_setup
  PROJECT="$(setup_project_scaffold "testapp")"
  source_layer "${REPO_ROOT}/lib/layers/python/src.sh"
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  source_layer "${REPO_ROOT}/lib/layers/python/azure-identity.sh"
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  source_layer "${REPO_ROOT}/lib/layers/python/azure-ai-foundry.sh"
}

teardown() {
  _common_teardown
}

# ── Core artifacts ─────────────────────────────────────────────────

@test "layer_azure_ai_foundry: creates src/{pkg}/foundry/" {
  apply_layer_azure_ai_foundry "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -d "${PROJECT}/src/testapp/foundry" ]
  assert [ -f "${PROJECT}/src/testapp/foundry/__init__.py" ]
  assert [ -f "${PROJECT}/src/testapp/foundry/client.py" ]
  assert [ -f "${PROJECT}/src/testapp/foundry/models.py" ]
  assert [ -f "${PROJECT}/src/testapp/foundry/connections.py" ]
}

@test "layer_azure_ai_foundry: requirements.txt contains azure-ai-projects" {
  apply_layer_azure_ai_foundry "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "azure-ai-projects" "${PROJECT}/requirements.txt"
}

@test "layer_azure_ai_foundry: .env.example contains AZURE_AI_PROJECT_ENDPOINT" {
  apply_layer_azure_ai_foundry "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "AZURE_AI_PROJECT_ENDPOINT" "${PROJECT}/.env.example"
}

@test "layer_azure_ai_foundry: test file created" {
  apply_layer_azure_ai_foundry "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -f "${PROJECT}/tests/unit/test_foundry.py" ]
  grep -Fq "test_raises_without_endpoint" "${PROJECT}/tests/unit/test_foundry.py"
}

# ── conftest fixture ──────────────────────────────────────────────

@test "layer_azure_ai_foundry: conftest has requires_foundry fixture" {
  apply_layer_azure_ai_foundry "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq 'requires_foundry' "${PROJECT}/tests/conftest.py"
}

# ── Import path (src layout) ─────────────────────────────────────

@test "layer_azure_ai_foundry: client.py import uses src layout prefix" {
  apply_layer_azure_ai_foundry "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "from testapp.auth.credential import" "${PROJECT}/src/testapp/foundry/client.py"
}

@test "layer_azure_ai_foundry: models.py import uses src layout prefix" {
  apply_layer_azure_ai_foundry "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "from testapp.foundry.client import" "${PROJECT}/src/testapp/foundry/models.py"
}

@test "layer_azure_ai_foundry: connections.py import uses src layout prefix" {
  apply_layer_azure_ai_foundry "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "from testapp.foundry.client import" "${PROJECT}/src/testapp/foundry/connections.py"
}

@test "layer_azure_ai_foundry: test_foundry.py uses src layout imports" {
  apply_layer_azure_ai_foundry "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "import testapp.foundry.client as client_mod" "${PROJECT}/tests/unit/test_foundry.py"
  grep -Fq "import testapp.foundry.models as models_mod" "${PROJECT}/tests/unit/test_foundry.py"
  grep -Fq "import testapp.foundry.connections as connections_mod" "${PROJECT}/tests/unit/test_foundry.py"
}

# ── Standalone mode (no FastAPI) ──────────────────────────────────

@test "layer_azure_ai_foundry: standalone main.py has foundry verification" {
  apply_layer_azure_ai_foundry "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "foundry_health" "${PROJECT}/src/testapp/main.py"
  grep -Fq "list_models" "${PROJECT}/src/testapp/main.py"
  grep -Fq "list_connections" "${PROJECT}/src/testapp/main.py"
}

@test "layer_azure_ai_foundry: standalone main.py import uses src prefix" {
  apply_layer_azure_ai_foundry "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "from testapp.foundry.client import" "${PROJECT}/src/testapp/main.py"
  grep -Fq "from testapp.foundry.models import" "${PROJECT}/src/testapp/main.py"
  grep -Fq "from testapp.foundry.connections import" "${PROJECT}/src/testapp/main.py"
}

# ── With FastAPI ──────────────────────────────────────────────────

@test "layer_azure_ai_foundry: with FastAPI → health check injected" {
  source_layer "${REPO_ROOT}/lib/layers/python/fastapi.sh"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_ai_foundry "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq 'health_status["azure_foundry"]' "${PROJECT}/src/testapp/main.py"
}

@test "layer_azure_ai_foundry: with FastAPI → all discovery routes injected" {
  source_layer "${REPO_ROOT}/lib/layers/python/fastapi.sh"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_ai_foundry "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq '/api/foundry/status' "${PROJECT}/src/testapp/main.py"
  grep -Fq '/api/models' "${PROJECT}/src/testapp/main.py"
  grep -Fq '/api/connections' "${PROJECT}/src/testapp/main.py"
}

@test "layer_azure_ai_foundry: with FastAPI → imports foundry modules" {
  source_layer "${REPO_ROOT}/lib/layers/python/fastapi.sh"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_ai_foundry "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "from testapp.foundry.client import" "${PROJECT}/src/testapp/main.py"
  grep -Fq "from testapp.foundry.models import" "${PROJECT}/src/testapp/main.py"
  grep -Fq "from testapp.foundry.connections import" "${PROJECT}/src/testapp/main.py"
}

# ── README ────────────────────────────────────────────────────────

@test "layer_azure_ai_foundry: README contains Azure AI Foundry section" {
  apply_layer_azure_ai_foundry "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq 'Azure AI Foundry' "${PROJECT}/README.md"
}

@test "layer_azure_ai_foundry: README has foundry/ in structure tree" {
  apply_layer_azure_ai_foundry "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq 'foundry/' "${PROJECT}/README.md"
}

# ── Idempotency ───────────────────────────────────────────────────

@test "layer_azure_ai_foundry: idempotent" {
  apply_layer_azure_ai_foundry "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local snap1="${TEST_TEMP}/snap1"
  mkdir -p "$snap1"
  cp -a "$PROJECT" "$snap1/project"

  apply_layer_azure_ai_foundry "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  diff -rq "$snap1/project" "$PROJECT"
}

# ── Metadata ──────────────────────────────────────────────────────

@test "layer_azure_ai_foundry: phase is infra" {
  local phase
  phase="$(grep -m1 '^_LAYER_PHASE=' "${REPO_ROOT}/lib/layers/python/azure-ai-foundry.sh" | cut -d'"' -f2)"
  assert_equal "$phase" "infra"
}

@test "layer_azure_ai_foundry: requires azure-identity" {
  local requires
  requires="$(grep -m1 '^_LAYER_REQUIRES=' "${REPO_ROOT}/lib/layers/python/azure-ai-foundry.sh" | cut -d'"' -f2)"
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

  # Apply azure-identity first (required dependency)
  apply_layer_azure_identity "$flat_project" "testapp" "python" "${flat_project}/.devcontainer" >&2
  echo "$flat_project"
}

@test "layer_azure_ai_foundry: flat layout → foundry/ at project root" {
  local flat_project; flat_project="$(_setup_flat_project)"
  apply_layer_azure_ai_foundry "$flat_project" "testapp" "python" "${flat_project}/.devcontainer"
  assert [ -d "${flat_project}/foundry" ]
  assert [ -f "${flat_project}/foundry/__init__.py" ]
  assert [ -f "${flat_project}/foundry/client.py" ]
  assert [ -f "${flat_project}/foundry/models.py" ]
  assert [ -f "${flat_project}/foundry/connections.py" ]
}

@test "layer_azure_ai_foundry: flat layout → no src prefix in imports" {
  local flat_project; flat_project="$(_setup_flat_project)"
  apply_layer_azure_ai_foundry "$flat_project" "testapp" "python" "${flat_project}/.devcontainer"
  # client.py should use bare import (no testapp. prefix)
  grep -Fq "from auth.credential import" "${flat_project}/foundry/client.py"
  # models.py and connections.py should use relative import
  grep -Fq "from .client import" "${flat_project}/foundry/models.py"
  grep -Fq "from .client import" "${flat_project}/foundry/connections.py"
}

@test "layer_azure_ai_foundry: flat layout → standalone main.py imports" {
  local flat_project; flat_project="$(_setup_flat_project)"
  apply_layer_azure_ai_foundry "$flat_project" "testapp" "python" "${flat_project}/.devcontainer"
  grep -Fq "foundry_health" "${flat_project}/main.py"
  grep -Fq "from foundry.client import" "${flat_project}/main.py"
  grep -Fq "from foundry.models import" "${flat_project}/main.py"
  grep -Fq "from foundry.connections import" "${flat_project}/main.py"
}

@test "layer_azure_ai_foundry: flat layout → test file uses bare imports" {
  local flat_project; flat_project="$(_setup_flat_project)"
  apply_layer_azure_ai_foundry "$flat_project" "testapp" "python" "${flat_project}/.devcontainer"
  assert [ -f "${flat_project}/tests/unit/test_foundry.py" ]
  grep -Fq "import foundry.client as client_mod" "${flat_project}/tests/unit/test_foundry.py"
  grep -Fq "import foundry.models as models_mod" "${flat_project}/tests/unit/test_foundry.py"
  grep -Fq "import foundry.connections as connections_mod" "${flat_project}/tests/unit/test_foundry.py"
}

@test "layer_azure_ai_foundry: flat layout + FastAPI → routes injected at root" {
  local flat_project; flat_project="$(_setup_flat_project)"
  source_layer "${REPO_ROOT}/lib/layers/python/fastapi.sh"
  apply_layer_fastapi "$flat_project" "testapp" "python" "${flat_project}/.devcontainer"
  apply_layer_azure_ai_foundry "$flat_project" "testapp" "python" "${flat_project}/.devcontainer"
  grep -Fq '/api/foundry/status' "${flat_project}/main.py"
  grep -Fq '/api/models' "${flat_project}/main.py"
  grep -Fq '/api/connections' "${flat_project}/main.py"
  grep -Fq 'health_status["azure_foundry"]' "${flat_project}/main.py"
}

@test "layer_azure_ai_foundry: flat layout + FastAPI → imports without prefix" {
  local flat_project; flat_project="$(_setup_flat_project)"
  source_layer "${REPO_ROOT}/lib/layers/python/fastapi.sh"
  apply_layer_fastapi "$flat_project" "testapp" "python" "${flat_project}/.devcontainer"
  apply_layer_azure_ai_foundry "$flat_project" "testapp" "python" "${flat_project}/.devcontainer"
  grep -Fq "from foundry.client import" "${flat_project}/main.py"
  grep -Fq "from foundry.models import" "${flat_project}/main.py"
  grep -Fq "from foundry.connections import" "${flat_project}/main.py"
}

@test "layer_azure_ai_foundry: flat layout → idempotent" {
  local flat_project; flat_project="$(_setup_flat_project)"
  apply_layer_azure_ai_foundry "$flat_project" "testapp" "python" "${flat_project}/.devcontainer"
  local snap1="${TEST_TEMP}/flat_snap1"
  mkdir -p "$snap1"
  cp -a "$flat_project" "$snap1/project"

  apply_layer_azure_ai_foundry "$flat_project" "testapp" "python" "${flat_project}/.devcontainer"
  diff -rq "$snap1/project" "$flat_project"
}
