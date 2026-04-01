#!/usr/bin/env bats
# tests/e2e/test_azure_chat_stack.bats — FastAPI + Azure Identity + Foundry + Chat (no credentials)
# Validates: graceful degradation when Azure credentials/endpoint are not available.
# The container starts successfully, /health reports degraded, chat routes return 500 (not 404).
#
# Uses docker build standalone + docker run (no compose — chat does not require compose)

setup_file() {
  load '../helpers/test_helper'
  _common_setup
  load './e2e_test_helper'

  progress "[test_azure_chat_stack] Setting up FastAPI + Azure Identity + Foundry + Chat stack..."

  if ! docker info >/dev/null 2>&1; then
    export BATS_DOCKER_SKIP="Docker not available"
    return 0
  fi

  export FILE_TEMP="$TEST_TEMP"
  export PROJECT="$(create_test_project "python" "src,fastapi,azure-identity,azure-ai-foundry,azure-ai-chat")"
  export IMAGE_TAG="bats-azure-chat-$$"
  export APP_PORT="$(find_free_port)"

  docker_build_image "$PROJECT" "$IMAGE_TAG" >&2
  export CONTAINER_ID="$(docker_run_detached "$IMAGE_TAG" "$APP_PORT" 8000)"

  sleep 2
  if ! docker inspect "$CONTAINER_ID" >/dev/null 2>&1; then
    echo "ERROR: Container exited immediately after start" >&2
    return 1
  fi

  if ! wait_for_http "http://localhost:${APP_PORT}/health" 90; then
    dump_container_logs "$CONTAINER_ID"
    return 1
  fi
}

teardown_file() {
  docker_stop_container "${CONTAINER_ID:-}" 2>/dev/null || true
  docker_remove_image "${IMAGE_TAG:-}" 2>/dev/null || true
  [[ -d "${FILE_TEMP:-}" ]] && rm -rf "$FILE_TEMP" 2>/dev/null || true
}

setup() {
  load '../helpers/test_helper'
  load './e2e_test_helper'
  if [[ -n "${BATS_DOCKER_SKIP:-}" ]]; then skip "$BATS_DOCKER_SKIP"; fi
}

# ── Health endpoint ───────────────────────────────────────────────

@test "azure_chat_stack: GET /health returns 200" {
  run curl -sf "http://localhost:${APP_PORT}/health"
  assert_success
  assert_output --partial '"status"'
}

@test "azure_chat_stack: health includes azure_foundry field (degraded)" {
  run curl -sf "http://localhost:${APP_PORT}/health"
  assert_success
  assert_output --partial '"azure_foundry"'
  assert_output --partial '"degraded"'
}

# ── Chat endpoints (routes exist, 500 without credentials) ───────

@test "azure_chat_stack: POST /api/chat route exists (not 404)" {
  run curl -so /dev/null -w '%{http_code}' \
    -X POST "http://localhost:${APP_PORT}/api/chat" \
    -H "Content-Type: application/json" \
    -d '{"message": "hello", "model": "gpt-4.1"}'
  assert_success
  refute_output '404'
}

@test "azure_chat_stack: POST /api/chat/stream route exists (not 404)" {
  run curl -so /dev/null -w '%{http_code}' \
    -X POST "http://localhost:${APP_PORT}/api/chat/stream" \
    -H "Content-Type: application/json" \
    -d '{"message": "hello", "model": "gpt-4.1"}'
  assert_success
  refute_output '404'
}

@test "azure_chat_stack: POST /api/chat without message returns 422" {
  run curl -so /dev/null -w '%{http_code}' \
    -X POST "http://localhost:${APP_PORT}/api/chat" \
    -H "Content-Type: application/json" \
    -d '{}'
  assert_success
  assert_output '422'
}

# ── Foundry endpoints still work ─────────────────────────────────

@test "azure_chat_stack: GET /api/foundry/status returns 200" {
  run curl -sf "http://localhost:${APP_PORT}/api/foundry/status"
  assert_success
  assert_output --partial '"connected"'
}

@test "azure_chat_stack: GET /api/models route exists" {
  run curl -so /dev/null -w '%{http_code}' "http://localhost:${APP_PORT}/api/models"
  assert_success
  refute_output '404'
}

# ── OpenAPI spec includes all routes ──────────────────────────────

@test "azure_chat_stack: OpenAPI spec lists chat endpoints" {
  run curl -sf "http://localhost:${APP_PORT}/openapi.json"
  assert_success
  assert_output --partial '/api/chat'
  assert_output --partial '/api/chat/stream'
}

@test "azure_chat_stack: OpenAPI spec lists foundry endpoints" {
  run curl -sf "http://localhost:${APP_PORT}/openapi.json"
  assert_success
  assert_output --partial '/api/foundry/status'
  assert_output --partial '/api/models'
  assert_output --partial '/api/connections'
}

# ── Identity endpoint (from azure-identity layer) ─────────────────

@test "azure_chat_stack: GET /api/identity returns 200" {
  run curl -sf "http://localhost:${APP_PORT}/api/identity"
  assert_success
  assert_output --partial '"authenticated"'
}

# ── Basic API functionality ───────────────────────────────────────

@test "azure_chat_stack: GET /docs returns Swagger UI" {
  run curl -sf "http://localhost:${APP_PORT}/docs"
  assert_success
  assert_output --partial "swagger"
}

@test "azure_chat_stack: container runs as non-root" {
  run docker exec "$CONTAINER_ID" whoami
  assert_success
  assert_output --partial "appuser"
}
