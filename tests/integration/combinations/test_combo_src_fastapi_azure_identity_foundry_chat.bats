#!/usr/bin/env bats
# tests/integration/combinations/test_combo_src_fastapi_azure_identity_foundry_chat.bats
# Validates: src + fastapi + azure-identity + azure-ai-foundry + azure-ai-chat combination.
# All three azure layers are self-contained — they create auth/, foundry/, chat/
# packages with opt-in routers and never modify main.py.

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

@test "combo full stack: chat is fully self-contained — main.py untouched" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local before_hash; before_hash="$(md5sum "${PROJECT}/src/testapp/main.py" | cut -d' ' -f1)"
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_ai_foundry "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_ai_chat "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local after_hash; after_hash="$(md5sum "${PROJECT}/src/testapp/main.py" | cut -d' ' -f1)"
  assert_equal "$before_hash" "$after_hash"
}

@test "combo full stack: identity + foundry + chat all expose routers in their packages" {
  _apply_full_stack
  grep -Fq '/identity' "${PROJECT}/src/testapp/auth/router.py"
  grep -Fq '/foundry/status' "${PROJECT}/src/testapp/foundry/router.py"
  grep -Fq '/chat' "${PROJECT}/src/testapp/chat/router.py"
  grep -Fq '/chat/stream' "${PROJECT}/src/testapp/chat/router.py"
}

# ── main.py untouched by any of the three layers ─────────────────────────

@test "combo full stack: no /api routes leaked into main.py" {
  _apply_full_stack
  ! grep -Fq '/api/identity' "${PROJECT}/src/testapp/main.py"
  ! grep -Fq '/api/foundry/status' "${PROJECT}/src/testapp/main.py"
  ! grep -Fq '/api/chat' "${PROJECT}/src/testapp/main.py"
}

# ── Import prefixes ──────────────────────────────────────────────

@test "combo full stack: imports stay inside their own packages — main.py free of layer imports" {
  _apply_full_stack
  # No layer imports leaked into main.py
  ! grep -Fq "from testapp.auth.credential import" "${PROJECT}/src/testapp/main.py"
  ! grep -Fq "from testapp.foundry.client import" "${PROJECT}/src/testapp/main.py"
  ! grep -Fq "from testapp.chat import" "${PROJECT}/src/testapp/main.py"
  ! grep -Fq "from testapp.chat.models import" "${PROJECT}/src/testapp/main.py"
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

@test "combo full stack: ChatRequest lives in chat/router.py, not main.py" {
  _apply_full_stack
  grep -Fq "ChatRequest" "${PROJECT}/src/testapp/chat/router.py"
  ! grep -Fq "ChatRequest" "${PROJECT}/src/testapp/main.py"
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
}
