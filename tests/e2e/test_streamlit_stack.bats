#!/usr/bin/env bats
# tests/docker/test_streamlit_stack.bats — Streamlit + Postgres
# Validates: build, port 8501, Streamlit health, initial HTML
#
# setup_file builds and starts the ENTIRE stack ONCE.
# streamlit layer creates the app service in compose.yaml (port 8501).

setup_file() {
  load '../helpers/test_helper'
  _common_setup
  load './e2e_test_helper'

  progress "[test_streamlit] Setting up Streamlit + Postgres stack..."

  if ! docker info >/dev/null 2>&1; then
    export BATS_DOCKER_SKIP="Docker not available"
    return 0
  fi

  export FILE_TEMP="$TEST_TEMP"
  export PROJECT="$(create_test_project "python" "src,streamlit,compose,postgres")"

  # Fix: rewrite dynamic port
  export APP_PORT="$(rewrite_compose_port "${PROJECT}/compose.yaml" 8501)"

  docker_build "$PROJECT" >&2
  docker_up "$PROJECT" >&2

  if ! wait_for_http "http://localhost:${APP_PORT}/_stcore/health" 90; then
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

@test "streamlit: health endpoint /_stcore/health responde ok" {
  run curl -sf "http://localhost:${APP_PORT}/_stcore/health"
  assert_success
  assert_output --partial "ok"
}

@test "streamlit: GET / returns HTML" {
  run curl -sf "http://localhost:${APP_PORT}/"
  assert_success
  assert_output --partial "<html"
}

@test "streamlit: postgres service running" {
  run docker compose -f "${PROJECT}/compose.yaml" ps --format json
  assert_output --partial "postgres"
}

@test "streamlit: container roda como non-root" {
  run run_in_container "$PROJECT" whoami
  assert_success
  assert_output --partial "appuser"
}

@test "streamlit: compose.yaml valid (config check)" {
  run docker compose -f "${PROJECT}/compose.yaml" --profile prod config --quiet
  assert_success
}
