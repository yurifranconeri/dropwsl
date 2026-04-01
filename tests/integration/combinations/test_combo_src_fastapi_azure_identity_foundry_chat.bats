#!/usr/bin/env bats
# tests/integration/combinations/test_combo_src_fastapi_azure_identity_foundry_chat.bats
# Validates: src + fastapi + azure-identity + azure-ai-foundry + azure-ai-chat combination.
# Chat (infra-inject phase) runs AFTER foundry (infra), so it must correctly
# detect the async API and inject routes + imports into an already-enriched main.py.

setup() {
  load '../../helpers/layer_test_helper'
  _common_setup
  PROJECT="$(setup_project_scaffold "testapp")"
  source_layer "${REPO_ROOT}/lib/layers/python/src.sh"
  source_layer "${REPO_ROOT}/lib/layers/python/fastapi.sh"
  source_layer "${REPO_ROOT}/lib/layers/python/azure-identity.sh"
  source_layer "${REPO_ROOT}/lib/layers/python/azure-ai-foundry.sh"
  source_layer "${REPO_ROOT}/lib/layers/python/azure-ai-chat.sh"
}

teardown() {
  _common_teardown
}

_apply_full_stack() {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_ai_foundry "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_ai_chat "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
}

# ── Core artifacts ────────────────────────────────────────────────

@test "combo full stack: all modules present" {
  _apply_full_stack
  assert [ -d "${PROJECT}/src/testapp/auth" ]
  assert [ -d "${PROJECT}/src/testapp/foundry" ]
  assert [ -d "${PROJECT}/src/testapp/chat" ]
  assert [ -f "${PROJECT}/src/testapp/chat/responses.py" ]
  assert [ -f "${PROJECT}/src/testapp/chat/completions.py" ]
  assert [ -f "${PROJECT}/src/testapp/chat/_common.py" ]
  assert [ -f "${PROJECT}/src/testapp/chat/models.py" ]
}

# ── Health checks ─────────────────────────────────────────────────

@test "combo full stack: foundry health check present (chat has no health)" {
  _apply_full_stack
  grep -Fq 'health_status["azure_identity"]' "${PROJECT}/src/testapp/main.py"
  grep -Fq 'health_status["azure_foundry"]' "${PROJECT}/src/testapp/main.py"
}

# ── All routes present ────────────────────────────────────────────

@test "combo full stack: all routes present in main.py" {
  _apply_full_stack
  grep -Fq '/api/identity' "${PROJECT}/src/testapp/main.py"
  grep -Fq '/api/foundry/status' "${PROJECT}/src/testapp/main.py"
  grep -Fq '/api/models' "${PROJECT}/src/testapp/main.py"
  grep -Fq '/api/connections' "${PROJECT}/src/testapp/main.py"
  grep -Fq '/api/chat' "${PROJECT}/src/testapp/main.py"
  grep -Fq '/api/chat/stream' "${PROJECT}/src/testapp/main.py"
}

# ── Import prefixes ──────────────────────────────────────────────

@test "combo full stack: all imports use src layout prefix" {
  _apply_full_stack
  grep -Fq "from testapp.auth.credential import" "${PROJECT}/src/testapp/main.py"
  grep -Fq "from testapp.foundry.client import" "${PROJECT}/src/testapp/main.py"
  grep -Fq "from testapp.chat import" "${PROJECT}/src/testapp/main.py"
  grep -Fq "from testapp.chat.models import" "${PROJECT}/src/testapp/main.py"
}

@test "combo full stack: chat responses.py uses src prefix for foundry import" {
  _apply_full_stack
  grep -Fq "from testapp.foundry.client import" "${PROJECT}/src/testapp/chat/responses.py"
}

@test "combo full stack: chat completions.py uses src prefix for foundry import" {
  _apply_full_stack
  grep -Fq "from testapp.foundry.client import" "${PROJECT}/src/testapp/chat/completions.py"
}

# ── Pydantic model in routes ─────────────────────────────────────

@test "combo full stack: ChatRequest used in main.py routes" {
  _apply_full_stack
  grep -Fq "ChatRequest" "${PROJECT}/src/testapp/main.py"
}

# ── Tests created ─────────────────────────────────────────────────

@test "combo full stack: both test files exist" {
  _apply_full_stack
  assert [ -f "${PROJECT}/tests/unit/test_foundry.py" ]
  assert [ -f "${PROJECT}/tests/unit/test_chat.py" ]
}

# ── Idempotency ───────────────────────────────────────────────────

@test "combo full stack: chat idempotent on re-apply" {
  _apply_full_stack
  # Snapshot chat-specific artifacts
  local snap1="${TEST_TEMP}/snap1"
  mkdir -p "$snap1"
  cp -a "${PROJECT}/src/testapp/chat" "$snap1/chat"
  cp "${PROJECT}/tests/unit/test_chat.py" "$snap1/test_chat.py"

  _apply_full_stack
  diff -rq "$snap1/chat" "${PROJECT}/src/testapp/chat"
  diff -q "$snap1/test_chat.py" "${PROJECT}/tests/unit/test_chat.py"
  # Verify routes not duplicated in main.py
  local count
  count="$(grep -c '/api/chat"' "${PROJECT}/src/testapp/main.py")"
  assert_equal "$count" "1"
}
