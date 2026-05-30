#!/usr/bin/env bats
# tests/integration/layer_python/test_layer_azure_ai_chat.bats
# Validates the self-contained chat/ package — never modifies main.py.

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

@test "layer_azure_ai_chat: creates src/{pkg}/chat/ with all files" {
  apply_layer_azure_ai_chat "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -d "${PROJECT}/src/testapp/chat" ]
  for f in __init__ __main__ _common responses completions models router ui; do
    assert [ -f "${PROJECT}/src/testapp/chat/${f}.py" ]
  done
}

@test "layer_azure_ai_chat: .env.example contains AZURE_AI_CHAT_MODEL" {
  apply_layer_azure_ai_chat "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "AZURE_AI_CHAT_MODEL" "${PROJECT}/.env.example"
}

@test "layer_azure_ai_chat: test file created" {
  apply_layer_azure_ai_chat "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -f "${PROJECT}/tests/unit/test_chat.py" ]
}

# ── Self-containment principle ────────────────────────────────────

@test "layer_azure_ai_chat: does NOT modify main.py" {
  local before_hash; before_hash="$(md5sum "${PROJECT}/src/testapp/main.py" | cut -d' ' -f1)"
  apply_layer_azure_ai_chat "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local after_hash; after_hash="$(md5sum "${PROJECT}/src/testapp/main.py" | cut -d' ' -f1)"
  assert_equal "$before_hash" "$after_hash"
}

@test "layer_azure_ai_chat: does NOT modify main.py even with FastAPI" {
  source_layer "${REPO_ROOT}/lib/layers/python/fastapi.sh"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local before_hash; before_hash="$(md5sum "${PROJECT}/src/testapp/main.py" | cut -d' ' -f1)"
  apply_layer_azure_ai_chat "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local after_hash; after_hash="$(md5sum "${PROJECT}/src/testapp/main.py" | cut -d' ' -f1)"
  assert_equal "$before_hash" "$after_hash"
}

@test "layer_azure_ai_chat: __main__.py is runnable form" {
  apply_layer_azure_ai_chat "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq 'if __name__ == "__main__"' "${PROJECT}/src/testapp/chat/__main__.py"
  grep -Fq 'sys.exit(main())' "${PROJECT}/src/testapp/chat/__main__.py"
}

@test "layer_azure_ai_chat: router.py exports APIRouter with chat routes" {
  apply_layer_azure_ai_chat "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "router = APIRouter" "${PROJECT}/src/testapp/chat/router.py"
  grep -Fq "/chat" "${PROJECT}/src/testapp/chat/router.py"
  grep -Fq "/chat/stream" "${PROJECT}/src/testapp/chat/router.py"
}

@test "layer_azure_ai_chat: ui.py exports render_chat_panel" {
  apply_layer_azure_ai_chat "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "def render_chat_panel" "${PROJECT}/src/testapp/chat/ui.py"
}

# ── Import paths (src layout) ─────────────────────────────────────

@test "layer_azure_ai_chat: responses.py uses src prefix for foundry import" {
  apply_layer_azure_ai_chat "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "from testapp.foundry.client import" "${PROJECT}/src/testapp/chat/responses.py"
}

@test "layer_azure_ai_chat: completions.py uses src prefix for foundry import" {
  apply_layer_azure_ai_chat "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "from testapp.foundry.client import" "${PROJECT}/src/testapp/chat/completions.py"
}

@test "layer_azure_ai_chat: chat submodules use relative imports between siblings" {
  apply_layer_azure_ai_chat "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "from ._common import" "${PROJECT}/src/testapp/chat/responses.py"
  grep -Fq "from ._common import" "${PROJECT}/src/testapp/chat/completions.py"
  grep -Fq "from .responses import" "${PROJECT}/src/testapp/chat/router.py"
}

@test "layer_azure_ai_chat: README integration snippets use src prefix" {
  apply_layer_azure_ai_chat "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "from testapp.chat.router import" "${PROJECT}/README.md"
  grep -Fq "from testapp.chat.ui import" "${PROJECT}/README.md"
  grep -Fq "python -m testapp.chat" "${PROJECT}/README.md"
}

# ── README ────────────────────────────────────────────────────────

@test "layer_azure_ai_chat: README contains Chat section" {
  apply_layer_azure_ai_chat "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq 'Chat (Responses' "${PROJECT}/README.md"
}

@test "layer_azure_ai_chat: README has chat/ in structure tree" {
  apply_layer_azure_ai_chat "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq '├── chat/' "${PROJECT}/README.md"
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

@test "layer_azure_ai_chat: phase is infra" {
  local phase
  phase="$(grep -m1 '^_LAYER_PHASE=' "${REPO_ROOT}/lib/layers/python/azure-ai-chat.sh" | cut -d'"' -f2)"
  assert_equal "$phase" "infra"
}

@test "layer_azure_ai_chat: requires azure-ai-foundry" {
  local requires
  requires="$(grep -m1 '^_LAYER_REQUIRES=' "${REPO_ROOT}/lib/layers/python/azure-ai-chat.sh" | cut -d'"' -f2)"
  assert_equal "$requires" "azure-ai-foundry"
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
  apply_layer_azure_ai_foundry "$flat_project" "testapp" "python" "${flat_project}/.devcontainer" >&2
  echo "$flat_project"
}

@test "layer_azure_ai_chat: flat layout → chat/ at project root" {
  local flat_project; flat_project="$(_setup_flat_project)"
  apply_layer_azure_ai_chat "$flat_project" "testapp" "python" "${flat_project}/.devcontainer"
  assert [ -d "${flat_project}/chat" ]
  for f in __init__ __main__ _common responses completions models router ui; do
    assert [ -f "${flat_project}/chat/${f}.py" ]
  done
}

@test "layer_azure_ai_chat: flat layout → no src prefix in imports" {
  local flat_project; flat_project="$(_setup_flat_project)"
  apply_layer_azure_ai_chat "$flat_project" "testapp" "python" "${flat_project}/.devcontainer"
  grep -Fq "from foundry.client import" "${flat_project}/chat/responses.py"
  grep -Fq "from foundry.client import" "${flat_project}/chat/completions.py"
  ! grep -Fq "from testapp.foundry" "${flat_project}/chat/responses.py"
}

@test "layer_azure_ai_chat: flat layout → does NOT modify main.py" {
  local flat_project; flat_project="$(_setup_flat_project)"
  local before_hash; before_hash="$(md5sum "${flat_project}/main.py" | cut -d' ' -f1)"
  apply_layer_azure_ai_chat "$flat_project" "testapp" "python" "${flat_project}/.devcontainer"
  local after_hash; after_hash="$(md5sum "${flat_project}/main.py" | cut -d' ' -f1)"
  assert_equal "$before_hash" "$after_hash"
}
