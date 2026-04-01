#!/usr/bin/env bats
# tests/docker/test_api_stack.bats — FastAPI + Postgres + Redis
# Validates: multi-service compose, health checks, DB connection, cache
#
# setup_file builds and starts the ENTIRE stack ONCE. Tests validate the running stack.

setup_file() {
  load '../helpers/test_helper'
  _common_setup
  load './e2e_test_helper'

  progress "[test_api_stack] Setting up FastAPI + Postgres + Redis stack..."

  if ! docker info >/dev/null 2>&1; then
    export BATS_DOCKER_SKIP="Docker not available"
    return 0
  fi

  export FILE_TEMP="$TEST_TEMP"
  export PROJECT="$(create_test_project "python" "src,fastapi,compose,postgres,redis")"
  export APP_PORT="$(rewrite_compose_port "${PROJECT}/compose.yaml" 8000)"

  docker_build "$PROJECT" >&2
  docker_up "$PROJECT" >&2

  # Diagnostics if wait_for_http fails
  if ! wait_for_http "http://localhost:${APP_PORT}/health" 90; then
    dump_compose_logs "$PROJECT"
    return 1
  fi
}

teardown_file() {
  docker_cleanup "${PROJECT:-}" 2>/dev/null || true
  [[ -d "${FILE_TEMP:-}" ]] && rm -rf "$FILE_TEMP" 2>/dev/null || true
}

setup() {
  load '../helpers/test_helper'
  load './e2e_test_helper'
  if [[ -n "${BATS_DOCKER_SKIP:-}" ]]; then skip "$BATS_DOCKER_SKIP"; fi
}

@test "api_stack: GET /health returns status ok" {
  run curl -sf "http://localhost:${APP_PORT}/health"
  assert_success
  assert_output --partial '"status"'
  assert_output --partial '"ok"'
}

@test "api_stack: health inclui postgres e redis" {
  run curl -sf "http://localhost:${APP_PORT}/health"
  assert_success
  assert_output --partial '"postgres"'
  assert_output --partial '"redis"'
}

@test "api_stack: GET /docs returns Swagger UI" {
  run curl -sf "http://localhost:${APP_PORT}/docs"
  assert_success
  assert_output --partial "swagger"
}

@test "api_stack: container roda como non-root" {
  run run_in_container "$PROJECT" whoami
  assert_success
  assert_output --partial "appuser"
}

@test "api_stack: postgres service running" {
  run docker compose -f "${PROJECT}/compose.yaml" ps --format json
  assert_output --partial "postgres"
}

@test "api_stack: redis service running" {
  run docker compose -f "${PROJECT}/compose.yaml" ps --format json
  assert_output --partial "redis"
}

@test "api_stack: compose.yaml valid (config check)" {
  run docker compose -f "${PROJECT}/compose.yaml" --profile prod config --quiet
  assert_success
}

@test "api_stack: devcontainer.json has compose network config" {
  local dc="${PROJECT}/.devcontainer/devcontainer.json"
  assert [ -f "$dc" ]
  grep -Fq '"initializeCommand"' "$dc"
  grep -Fq '"runArgs"' "$dc"
}

@test "api_stack: compose network name matches devcontainer runArgs" {
  local dc="${PROJECT}/.devcontainer/devcontainer.json"
  # Extract network name from compose.yaml
  local net_name
  net_name="$(grep 'name:' "${PROJECT}/compose.yaml" | head -n1 | awk '{print $2}')"
  assert [ -n "$net_name" ]
  grep -Fq "$net_name" "$dc"
}

@test "api_stack: uv applied by default" {
  grep -Fq 'ghcr.io/astral-sh/uv' "${PROJECT}/.devcontainer/Dockerfile"
}

@test "api_stack: engine.py has compose hostname default (not RuntimeError)" {
  grep -Fq '@postgres:5432' "${PROJECT}/src/"*/db/engine.py
  ! grep -Fq 'RuntimeError' "${PROJECT}/src/"*/db/engine.py
}

@test "api_stack: client.py has compose hostname default (not RuntimeError)" {
  grep -Fq 'redis://redis:6379/0' "${PROJECT}/src/"*/cache/client.py
  ! grep -Fq 'RuntimeError' "${PROJECT}/src/"*/cache/client.py
}
