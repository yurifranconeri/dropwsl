#!/usr/bin/env bats
# tests/integration/layer_python/test_layer_azure_ai_chat.bats

setup() {
  load '../../helpers/layer_test_helper'
  _common_setup
  PROJECT="$(setup_project_scaffold "testapp")"
  source_layer "${REPO_ROOT}/lib/layers/python/src.sh"
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  source_layer "${REPO_ROOT}/lib/layers/python/azure-identity.sh"
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  source_layer "${REPO_ROOT}/lib/layers/python/azure-ai-foundry.sh"
  apply_layer_azure_ai_foundry "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  source_layer "${REPO_ROOT}/lib/layers/python/azure-ai-chat.sh"
}

teardown() {
  _common_teardown
}

# ── Core artifacts ─────────────────────────────────────────────────

@test "layer_azure_ai_chat: creates src/{pkg}/chat/" {
  apply_layer_azure_ai_chat "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -d "${PROJECT}/src/testapp/chat" ]
  assert [ -f "${PROJECT}/src/testapp/chat/__init__.py" ]
  assert [ -f "${PROJECT}/src/testapp/chat/_common.py" ]
  assert [ -f "${PROJECT}/src/testapp/chat/responses.py" ]
  assert [ -f "${PROJECT}/src/testapp/chat/completions.py" ]
  assert [ -f "${PROJECT}/src/testapp/chat/models.py" ]
}

@test "layer_azure_ai_chat: .env.example contains AZURE_AI_CHAT_MODEL" {
  apply_layer_azure_ai_chat "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "AZURE_AI_CHAT_MODEL" "${PROJECT}/.env.example"
}

@test "layer_azure_ai_chat: test file created" {
  apply_layer_azure_ai_chat "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -f "${PROJECT}/tests/unit/test_chat.py" ]
  grep -Fq "test_basic_message" "${PROJECT}/tests/unit/test_chat.py"
}

# ── Import path (src layout) ─────────────────────────────────────

@test "layer_azure_ai_chat: responses.py import uses src layout prefix for foundry" {
  apply_layer_azure_ai_chat "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "from testapp.foundry.client import" "${PROJECT}/src/testapp/chat/responses.py"
}

@test "layer_azure_ai_chat: completions.py import uses src layout prefix for foundry" {
  apply_layer_azure_ai_chat "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "from testapp.foundry.client import" "${PROJECT}/src/testapp/chat/completions.py"
}

@test "layer_azure_ai_chat: __init__.py import uses src layout prefix" {
  apply_layer_azure_ai_chat "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "from testapp.chat.responses import" "${PROJECT}/src/testapp/chat/__init__.py"
  grep -Fq "from testapp.chat.completions import" "${PROJECT}/src/testapp/chat/__init__.py"
  grep -Fq "from testapp.chat.models import" "${PROJECT}/src/testapp/chat/__init__.py"
  grep -Fq "from testapp.chat._common import" "${PROJECT}/src/testapp/chat/__init__.py"
}

@test "layer_azure_ai_chat: test_chat.py uses src layout imports" {
  apply_layer_azure_ai_chat "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "import testapp.chat.responses as responses_mod" "${PROJECT}/tests/unit/test_chat.py"
  grep -Fq "import testapp.chat.completions as completions_mod" "${PROJECT}/tests/unit/test_chat.py"
  grep -Fq "import testapp.chat._common as common_mod" "${PROJECT}/tests/unit/test_chat.py"
  grep -Fq "from testapp.chat.models import" "${PROJECT}/tests/unit/test_chat.py"
}

# ── Standalone mode (no FastAPI) ──────────────────────────────────

@test "layer_azure_ai_chat: standalone main.py has send_message" {
  apply_layer_azure_ai_chat "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "send_message" "${PROJECT}/src/testapp/main.py"
}

@test "layer_azure_ai_chat: standalone main.py import uses src prefix" {
  apply_layer_azure_ai_chat "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "from testapp.chat.responses import" "${PROJECT}/src/testapp/main.py" || \
    grep -Fq "from testapp.chat import" "${PROJECT}/src/testapp/main.py" || \
    grep -Fq "from testapp.foundry.client import" "${PROJECT}/src/testapp/main.py"
}

# ── With FastAPI ──────────────────────────────────────────────────

@test "layer_azure_ai_chat: with FastAPI → chat routes injected" {
  source_layer "${REPO_ROOT}/lib/layers/python/fastapi.sh"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_ai_foundry "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_ai_chat "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq '/api/chat' "${PROJECT}/src/testapp/main.py"
  grep -Fq '/api/chat/stream' "${PROJECT}/src/testapp/main.py"
}

@test "layer_azure_ai_chat: with FastAPI → imports chat modules" {
  source_layer "${REPO_ROOT}/lib/layers/python/fastapi.sh"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_ai_foundry "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_ai_chat "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "from testapp.chat import" "${PROJECT}/src/testapp/main.py"
  grep -Fq "from testapp.chat.models import" "${PROJECT}/src/testapp/main.py"
}

@test "layer_azure_ai_chat: with FastAPI → ChatRequest in routes" {
  source_layer "${REPO_ROOT}/lib/layers/python/fastapi.sh"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_ai_foundry "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_ai_chat "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "ChatRequest" "${PROJECT}/src/testapp/main.py"
}

# ── README ────────────────────────────────────────────────────────

@test "layer_azure_ai_chat: README contains Chat section" {
  apply_layer_azure_ai_chat "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq 'Chat (Responses' "${PROJECT}/README.md"
}

@test "layer_azure_ai_chat: README has chat/ in structure tree" {
  apply_layer_azure_ai_chat "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq 'chat/' "${PROJECT}/README.md"
}

# ── Idempotency ───────────────────────────────────────────────────

@test "layer_azure_ai_chat: idempotent" {
  apply_layer_azure_ai_chat "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local snap1="${TEST_TEMP}/snap1"
  mkdir -p "$snap1"
  cp -a "$PROJECT" "$snap1/project"

  apply_layer_azure_ai_chat "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  diff -rq "$snap1/project" "$PROJECT"
}

# ── Metadata ──────────────────────────────────────────────────────

@test "layer_azure_ai_chat: phase is infra-inject" {
  local phase
  phase="$(grep -m1 '^_LAYER_PHASE=' "${REPO_ROOT}/lib/layers/python/azure-ai-chat.sh" | cut -d'"' -f2)"
  assert_equal "$phase" "infra-inject"
}

@test "layer_azure_ai_chat: requires azure-ai-foundry" {
  local requires
  requires="$(grep -m1 '^_LAYER_REQUIRES=' "${REPO_ROOT}/lib/layers/python/azure-ai-chat.sh" | cut -d'"' -f2)"
  assert_equal "$requires" "azure-ai-foundry"
}

# ── Flat layout (no src/) ─────────────────────────────────────────

_setup_flat_project_with_foundry() {
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

  # Apply prerequisites
  apply_layer_azure_identity "$flat_project" "testapp" "python" "${flat_project}/.devcontainer" >&2
  apply_layer_azure_ai_foundry "$flat_project" "testapp" "python" "${flat_project}/.devcontainer" >&2
  echo "$flat_project"
}

@test "layer_azure_ai_chat: flat layout → chat/ at project root" {
  local flat_project; flat_project="$(_setup_flat_project_with_foundry)"
  apply_layer_azure_ai_chat "$flat_project" "testapp" "python" "${flat_project}/.devcontainer"
  assert [ -d "${flat_project}/chat" ]
  assert [ -f "${flat_project}/chat/__init__.py" ]
  assert [ -f "${flat_project}/chat/_common.py" ]
  assert [ -f "${flat_project}/chat/responses.py" ]
  assert [ -f "${flat_project}/chat/completions.py" ]
  assert [ -f "${flat_project}/chat/models.py" ]
}

@test "layer_azure_ai_chat: flat layout → no src prefix in imports" {
  local flat_project; flat_project="$(_setup_flat_project_with_foundry)"
  apply_layer_azure_ai_chat "$flat_project" "testapp" "python" "${flat_project}/.devcontainer"
  # responses.py + completions.py should use bare foundry import
  grep -Fq "from foundry.client import" "${flat_project}/chat/responses.py"
  grep -Fq "from foundry.client import" "${flat_project}/chat/completions.py"
  # __init__.py should use relative imports
  grep -Fq "from .responses import" "${flat_project}/chat/__init__.py"
  grep -Fq "from .completions import" "${flat_project}/chat/__init__.py"
  grep -Fq "from .models import" "${flat_project}/chat/__init__.py"
  grep -Fq "from ._common import" "${flat_project}/chat/__init__.py"
}

@test "layer_azure_ai_chat: flat layout → test uses bare imports" {
  local flat_project; flat_project="$(_setup_flat_project_with_foundry)"
  apply_layer_azure_ai_chat "$flat_project" "testapp" "python" "${flat_project}/.devcontainer"
  grep -Fq "import chat.responses as responses_mod" "${flat_project}/tests/unit/test_chat.py"
  grep -Fq "import chat.completions as completions_mod" "${flat_project}/tests/unit/test_chat.py"
  grep -Fq "import chat._common as common_mod" "${flat_project}/tests/unit/test_chat.py"
  grep -Fq "from chat.models import" "${flat_project}/tests/unit/test_chat.py"
}
