#!/usr/bin/env bats
# tests/docker/test_minimal.bats — Base Python without layers
# Validates: multi-stage Dockerfile, CMD python main.py, non-root user
#
# Uses standalone docker build (no compose — base template has no compose.yaml)

setup_file() {
  load '../helpers/test_helper'
  _common_setup
  load './e2e_test_helper'

  progress "[test_minimal] Setting up base Python image..."

  if ! docker info >/dev/null 2>&1; then
    export BATS_DOCKER_SKIP="Docker not available"
    return 0
  fi

  export FILE_TEMP="$TEST_TEMP"
  export PROJECT="$(create_test_project "python" "")"
  export IMAGE_TAG="bats-minimal-$$"

  docker_build_image "$PROJECT" "$IMAGE_TAG" >&2
}

teardown_file() {
  docker_remove_image "${IMAGE_TAG:-}" 2>/dev/null || true
  [[ -d "${FILE_TEMP:-}" ]] && rm -rf "$FILE_TEMP" 2>/dev/null || true
}

setup() {
  load '../helpers/test_helper'
  load './e2e_test_helper'
  if [[ -n "${BATS_DOCKER_SKIP:-}" ]]; then skip "$BATS_DOCKER_SKIP"; fi
}

@test "minimal: docker build success" {
  run docker image inspect "$IMAGE_TAG"
  assert_success
}

@test "minimal: container runs main.py and prints Hello" {
  run docker_run_oneshot "$IMAGE_TAG"
  assert_success
  assert_output --partial "Hello"
}

@test "minimal: python 3.12 accessible in container" {
  run docker_run_oneshot "$IMAGE_TAG" python -c "import sys; print(sys.version)"
  assert_success
  assert_output --partial "3.12"
}

@test "minimal: container runs as non-root (appuser)" {
  run docker_run_oneshot "$IMAGE_TAG" whoami
  assert_success
  assert_output --partial "appuser"
}

@test "minimal: pip available in runtime" {
  run docker_run_oneshot "$IMAGE_TAG" pip --version
  assert_success
  assert_output --partial "pip"
}
