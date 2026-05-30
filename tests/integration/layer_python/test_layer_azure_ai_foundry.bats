#!/usr/bin/env bats
# tests/integration/layer_python/test_layer_azure_ai_foundry.bats
# Validates the self-contained foundry/ package — never modifies main.py.

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

@test "layer_azure_ai_foundry: creates src/{pkg}/foundry/ with all files" {
  apply_layer_azure_ai_foundry "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -d "${PROJECT}/src/testapp/foundry" ]
  for f in __init__ __main__ client models connections router ui; do
    assert [ -f "${PROJECT}/src/testapp/foundry/${f}.py" ]
  done
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

# ── Self-containment principle ────────────────────────────────────

@test "layer_azure_ai_foundry: does NOT modify main.py" {
  local before_hash; before_hash="$(md5sum "${PROJECT}/src/testapp/main.py" | cut -d' ' -f1)"
  apply_layer_azure_ai_foundry "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local after_hash; after_hash="$(md5sum "${PROJECT}/src/testapp/main.py" | cut -d' ' -f1)"
  assert_equal "$before_hash" "$after_hash"
}

@test "layer_azure_ai_foundry: does NOT modify main.py even with FastAPI" {
  source_layer "${REPO_ROOT}/lib/layers/python/fastapi.sh"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local before_hash; before_hash="$(md5sum "${PROJECT}/src/testapp/main.py" | cut -d' ' -f1)"
  apply_layer_azure_ai_foundry "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local after_hash; after_hash="$(md5sum "${PROJECT}/src/testapp/main.py" | cut -d' ' -f1)"
  assert_equal "$before_hash" "$after_hash"
}

@test "layer_azure_ai_foundry: __main__.py is runnable form" {
  apply_layer_azure_ai_foundry "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq 'if __name__ == "__main__"' "${PROJECT}/src/testapp/foundry/__main__.py"
  grep -Fq 'sys.exit(main())' "${PROJECT}/src/testapp/foundry/__main__.py"
}

@test "layer_azure_ai_foundry: router.py exports APIRouter with foundry routes" {
  apply_layer_azure_ai_foundry "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "router = APIRouter" "${PROJECT}/src/testapp/foundry/router.py"
  grep -Fq "/foundry/status" "${PROJECT}/src/testapp/foundry/router.py"
  grep -Fq "/models" "${PROJECT}/src/testapp/foundry/router.py"
  grep -Fq "/connections" "${PROJECT}/src/testapp/foundry/router.py"
}

@test "layer_azure_ai_foundry: ui.py exports render_foundry_panel" {
  apply_layer_azure_ai_foundry "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "def render_foundry_panel" "${PROJECT}/src/testapp/foundry/ui.py"
}

# ── conftest fixture ──────────────────────────────────────────────

@test "layer_azure_ai_foundry: conftest has requires_foundry fixture" {
  apply_layer_azure_ai_foundry "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq 'requires_foundry' "${PROJECT}/tests/conftest.py"
}

# ── Import paths (src layout) ─────────────────────────────────────

@test "layer_azure_ai_foundry: client.py uses src layout prefix for auth import" {
  apply_layer_azure_ai_foundry "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "from testapp.auth.credential import" "${PROJECT}/src/testapp/foundry/client.py"
}

@test "layer_azure_ai_foundry: foundry submodules use relative imports" {
  apply_layer_azure_ai_foundry "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "from .client import" "${PROJECT}/src/testapp/foundry/models.py"
  grep -Fq "from .client import" "${PROJECT}/src/testapp/foundry/connections.py"
}

@test "layer_azure_ai_foundry: test file uses src layout imports" {
  apply_layer_azure_ai_foundry "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "import testapp.foundry.client as client_mod" "${PROJECT}/tests/unit/test_foundry.py"
}

@test "layer_azure_ai_foundry: README integration snippets use src prefix" {
  apply_layer_azure_ai_foundry "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "from testapp.foundry.router import" "${PROJECT}/README.md"
  grep -Fq "from testapp.foundry.ui import" "${PROJECT}/README.md"
  grep -Fq "python -m testapp.foundry" "${PROJECT}/README.md"
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
  apply_layer_azure_identity "$flat_project" "testapp" "python" "${flat_project}/.devcontainer" >&2
  echo "$flat_project"
}

@test "layer_azure_ai_foundry: flat layout → foundry/ at project root" {
  local flat_project; flat_project="$(_setup_flat_project)"
  apply_layer_azure_ai_foundry "$flat_project" "testapp" "python" "${flat_project}/.devcontainer"
  assert [ -d "${flat_project}/foundry" ]
  for f in __init__ __main__ client models connections router ui; do
    assert [ -f "${flat_project}/foundry/${f}.py" ]
  done
}

@test "layer_azure_ai_foundry: flat layout → no src prefix in imports" {
  local flat_project; flat_project="$(_setup_flat_project)"
  apply_layer_azure_ai_foundry "$flat_project" "testapp" "python" "${flat_project}/.devcontainer"
  grep -Fq "from auth.credential import" "${flat_project}/foundry/client.py"
  grep -Fq "from .client import" "${flat_project}/foundry/models.py"
}

@test "layer_azure_ai_foundry: flat layout → does NOT modify main.py" {
  local flat_project; flat_project="$(_setup_flat_project)"
  local before_hash; before_hash="$(md5sum "${flat_project}/main.py" | cut -d' ' -f1)"
  apply_layer_azure_ai_foundry "$flat_project" "testapp" "python" "${flat_project}/.devcontainer"
  local after_hash; after_hash="$(md5sum "${flat_project}/main.py" | cut -d' ' -f1)"
  assert_equal "$before_hash" "$after_hash"
}
