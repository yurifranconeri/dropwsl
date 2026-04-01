#!/usr/bin/env bats
# tests/e2e/test_azure_identity_stack.bats — FastAPI + Azure Identity (no credentials)
# Validates: graceful degradation when Azure credentials are not available.
# The container starts successfully, /health reports degraded, /api/identity reports error.
#
# Uses docker build standalone + docker run (without compose — azure-identity does not require compose)

setup_file() {
  load '../helpers/test_helper'
  _common_setup
  load './e2e_test_helper'

  progress "[test_azure_identity_stack] Setting up FastAPI + Azure Identity stack..."

  if ! docker info >/dev/null 2>&1; then
    export BATS_DOCKER_SKIP="Docker not available"
    return 0
  fi

  export FILE_TEMP="$TEST_TEMP"
  export PROJECT="$(create_test_project "python" "src,fastapi,azure-identity")"
  export IMAGE_TAG="bats-azure-identity-$$"
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

@test "azure_identity_stack: GET /health returns 200" {
  run curl -sf "http://localhost:${APP_PORT}/health"
  assert_success
  assert_output --partial '"status"'
}

@test "azure_identity_stack: health includes azure_identity field" {
  run curl -sf "http://localhost:${APP_PORT}/health"
  assert_success
  assert_output --partial '"azure_identity"'
}

@test "azure_identity_stack: health azure_identity is degraded (no credentials)" {
  run curl -sf "http://localhost:${APP_PORT}/health"
  assert_success
  # Without az login or env vars, credential_health() returns False → degraded
  assert_output --partial '"degraded"'
}

# ── Identity endpoint ─────────────────────────────────────────────

@test "azure_identity_stack: GET /api/identity returns 200" {
  run curl -sf "http://localhost:${APP_PORT}/api/identity"
  assert_success
  assert_output --partial '"authenticated"'
}

@test "azure_identity_stack: /api/identity reports not authenticated" {
  run curl -sf "http://localhost:${APP_PORT}/api/identity"
  assert_success
  assert_output --partial '"authenticated":false'
  assert_output --partial 'az login'
}

# ── Basic API functionality ───────────────────────────────────────

@test "azure_identity_stack: GET /docs returns Swagger UI" {
  run curl -sf "http://localhost:${APP_PORT}/docs"
  assert_success
  assert_output --partial "swagger"
}

@test "azure_identity_stack: container runs as non-root" {
  run docker exec "$CONTAINER_ID" whoami
  assert_success
  assert_output --partial "appuser"
}
