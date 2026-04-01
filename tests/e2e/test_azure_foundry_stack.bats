#!/usr/bin/env bats
# tests/e2e/test_azure_foundry_stack.bats — FastAPI + Azure Identity + Azure AI Foundry (no credentials)
# Validates: graceful degradation when Azure credentials/endpoint are not available.
# The container starts successfully, /health reports degraded, /api/foundry/status reports error.
#
# Uses docker build standalone + docker run (no compose — foundry does not require compose)

setup_file() {
  load '../helpers/test_helper'
  _common_setup
  load './e2e_test_helper'

  progress "[test_azure_foundry_stack] Setting up FastAPI + Azure Identity + Foundry stack..."

  if ! docker info >/dev/null 2>&1; then
    export BATS_DOCKER_SKIP="Docker not available"
    return 0
  fi

  export FILE_TEMP="$TEST_TEMP"
  export PROJECT="$(create_test_project "python" "src,fastapi,azure-identity,azure-ai-foundry")"
  export IMAGE_TAG="bats-azure-foundry-$$"
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

@test "azure_foundry_stack: GET /health returns 200" {
  run curl -sf "http://localhost:${APP_PORT}/health"
  assert_success
  assert_output --partial '"status"'
}

@test "azure_foundry_stack: health includes azure_identity field" {
  run curl -sf "http://localhost:${APP_PORT}/health"
  assert_success
  assert_output --partial '"azure_identity"'
}

@test "azure_foundry_stack: health includes azure_foundry field" {
  run curl -sf "http://localhost:${APP_PORT}/health"
  assert_success
  assert_output --partial '"azure_foundry"'
}

@test "azure_foundry_stack: health azure_foundry is degraded (no endpoint)" {
  run curl -sf "http://localhost:${APP_PORT}/health"
  assert_success
  assert_output --partial '"degraded"'
}

# ── Foundry status endpoint ───────────────────────────────────────

@test "azure_foundry_stack: GET /api/foundry/status returns 200" {
  run curl -sf "http://localhost:${APP_PORT}/api/foundry/status"
  assert_success
  assert_output --partial '"connected"'
}

@test "azure_foundry_stack: /api/foundry/status reports not connected" {
  run curl -sf "http://localhost:${APP_PORT}/api/foundry/status"
  assert_success
  assert_output --partial '"connected":false'
}

@test "azure_foundry_stack: /api/foundry/status has error message" {
  run curl -sf "http://localhost:${APP_PORT}/api/foundry/status"
  assert_success
  assert_output --partial '"error"'
  assert_output --partial 'AZURE_AI_PROJECT_ENDPOINT'
}

# ── Models endpoint ───────────────────────────────────────────────

@test "azure_foundry_stack: GET /api/models route exists (500 without endpoint)" {
  run curl -so /dev/null -w '%{http_code}' "http://localhost:${APP_PORT}/api/models"
  assert_success
  # 500 expected without credentials (ValueError from get_project_client)
  # but route must exist (not 404)
  refute_output '404'
}

@test "azure_foundry_stack: GET /api/models/{name} returns 404 or 500 (not 404 route)" {
  run curl -so /dev/null -w '%{http_code}' "http://localhost:${APP_PORT}/api/models/nonexistent"
  assert_success
  refute_output '404'
  # Without endpoint, get_project_client raises ValueError → 500
  # With endpoint but non-existent model → KeyError → 404
  # Either way, the route exists
}

# ── Connections endpoint ──────────────────────────────────────────

@test "azure_foundry_stack: GET /api/connections route exists (500 without endpoint)" {
  run curl -so /dev/null -w '%{http_code}' "http://localhost:${APP_PORT}/api/connections"
  assert_success
  refute_output '404'
}

@test "azure_foundry_stack: GET /api/connections/default/{type} route exists" {
  run curl -so /dev/null -w '%{http_code}' "http://localhost:${APP_PORT}/api/connections/default/AzureOpenAI"
  assert_success
  refute_output '404'
}

# ── OpenAPI spec includes all foundry routes ──────────────────────

@test "azure_foundry_stack: OpenAPI spec lists foundry endpoints" {
  run curl -sf "http://localhost:${APP_PORT}/openapi.json"
  assert_success
  assert_output --partial '/api/foundry/status'
  assert_output --partial '/api/models'
  assert_output --partial '/api/connections'
}

# ── Identity endpoint (from azure-identity layer) ─────────────────

@test "azure_foundry_stack: GET /api/identity returns 200" {
  run curl -sf "http://localhost:${APP_PORT}/api/identity"
  assert_success
  assert_output --partial '"authenticated"'
}

# ── Basic API functionality ───────────────────────────────────────

@test "azure_foundry_stack: GET /docs returns Swagger UI" {
  run curl -sf "http://localhost:${APP_PORT}/docs"
  assert_success
  assert_output --partial "swagger"
}

@test "azure_foundry_stack: container runs as non-root" {
  run docker exec "$CONTAINER_ID" whoami
  assert_success
  assert_output --partial "appuser"
}
