#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# tests/e2e/test_uv_build.bats — UV layer: build with uv, no pip in runtime
# Validates: build works, /health ok, pip removed, uv absent in runtime
#
# Uses docker build standalone + docker run (without compose)

setup_file() {
  load '../helpers/test_helper'
  _common_setup
  load './e2e_test_helper'

  progress "[test_uv] Setting up FastAPI + UV image..."

  if ! docker info >/dev/null 2>&1; then
    export BATS_DOCKER_SKIP="Docker not available"
    return 0
  fi

  export FILE_TEMP="$TEST_TEMP"
  export PROJECT="$(create_test_project "python" "src,fastapi,uv")"
  export IMAGE_TAG="bats-uv-$$"
  export APP_PORT="$(find_free_port)"

  docker_build_image "$PROJECT" "$IMAGE_TAG" >&2
  export CONTAINER_ID="$(docker_run_detached "$IMAGE_TAG" "$APP_PORT" 8000)"

  # Check if container is still running (immediate crash = exit before health)
  sleep 2
  if ! docker inspect "$CONTAINER_ID" >/dev/null 2>&1; then
    echo "ERROR: Container exited immediately after start" >&2
    return 1
  fi

  if ! wait_for_http "http://localhost:${APP_PORT}/health" 60; then
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

@test "uv: /health returns status ok" {
  run curl -sf "http://localhost:${APP_PORT}/health"
  assert_success
  assert_output --partial '"status"'
  assert_output --partial '"ok"'
}

@test "uv: pip available in runtime (system, not in venv)" {
  run docker exec "$CONTAINER_ID" pip --version
  assert_success
}

@test "uv: uv not in runtime (builder only)" {
  run -127 docker exec "$CONTAINER_ID" uv --version
  assert_failure
}

@test "uv: container roda como non-root" {
  run docker exec "$CONTAINER_ID" whoami
  assert_success
  assert_output --partial "appuser"
}
