#!/usr/bin/env bats
# tests/e2e/test_workspace_stack.bats — Workspace multi-service (api + worker)
# Validates: workspace_init, 2 services with FastAPI, compose at root,
#         ambos servem /health, postgres compartilhado, estrutura correta.
#
# setup_file creates the workspace, builds and starts EVERYTHING once.

setup_file() {
  load '../helpers/test_helper'
  _common_setup
  load './e2e_test_helper'

  progress "[test_workspace] Setting up workspace with 2 services..."

  if ! docker info >/dev/null 2>&1; then
    export BATS_DOCKER_SKIP="Docker not available"
    return 0
  fi

  export FILE_TEMP="$TEST_TEMP"
  export PROJECTS_DIR="${TEST_TEMP}/projects"
  mkdir -p "$PROJECTS_DIR"

  local ws_name="ws-$$-${RANDOM}"
  export COMPOSE_PROJECT_NAME="${ws_name}"

  # Service 1: api (fastapi + local postgres)
  progress "Creating service 'api'..."
  new_project "$ws_name" "python" "src,fastapi,postgres,compose" "api" >&2

  # Service 2: worker (fastapi only — simples)
  progress "Creating service 'worker'..."
  new_project "$ws_name" "python" "src,fastapi" "worker" >&2

  export WORKSPACE="${PROJECTS_DIR}/${ws_name}"

  # Rewrite ports to dynamic free ports (avoid collisions)
  local compose_file="${WORKSPACE}/compose.yaml"

  # api service gets port 8001:8000 from workspace_compose_service
  local api_ext; api_ext="$(find_free_port)"
  sed -i "0,/\"8001:8000\"/{s|\"8001:8000\"|\"${api_ext}:8000\"|}" "$compose_file"
  export API_PORT="$api_ext"

  # worker service gets port 8002:8000
  local worker_ext; worker_ext="$(find_free_port)"
  sed -i "s|\"8002:8000\"|\"${worker_ext}:8000\"|" "$compose_file"
  export WORKER_PORT="$worker_ext"

  # Build and start
  _run_with_dots "Building workspace images..." \
    docker compose -f "$compose_file" build 2>&1 >&2
  _run_with_dots "Starting workspace services..." \
    docker compose -f "$compose_file" up -d --wait --wait-timeout 120 2>&1 >&2

  if ! wait_for_http "http://localhost:${API_PORT}/health" 90; then
    dump_compose_logs "$WORKSPACE"
    return 1
  fi

  if ! wait_for_http "http://localhost:${WORKER_PORT}/health" 90; then
    dump_compose_logs "$WORKSPACE"
    return 1
  fi
}

teardown_file() {
  if [[ -f "${WORKSPACE:-}/compose.yaml" ]]; then
    docker compose -f "${WORKSPACE}/compose.yaml" down -v --remove-orphans --timeout 10 2>/dev/null || true
  fi
  [[ -d "${FILE_TEMP:-}" ]] && rm -rf "$FILE_TEMP" 2>/dev/null || true
}

setup() {
  load '../helpers/test_helper'
  load './e2e_test_helper'
  if [[ -n "${BATS_DOCKER_SKIP:-}" ]]; then skip "$BATS_DOCKER_SKIP"; fi
}

# ---- Structure tests ----

@test "workspace: services/ directory exists with api and worker" {
  assert [ -d "${WORKSPACE}/services/api" ]
  assert [ -d "${WORKSPACE}/services/worker" ]
}

@test "workspace: .devcontainer/ has per-service dirs" {
  assert [ -d "${WORKSPACE}/.devcontainer/api" ]
  assert [ -d "${WORKSPACE}/.devcontainer/worker" ]
  assert [ -f "${WORKSPACE}/.devcontainer/api/Dockerfile" ]
  assert [ -f "${WORKSPACE}/.devcontainer/worker/Dockerfile" ]
}

@test "workspace: compose.yaml at workspace root (not in services)" {
  assert [ -f "${WORKSPACE}/compose.yaml" ]
  assert [ ! -f "${WORKSPACE}/services/api/compose.yaml" ]
  assert [ ! -f "${WORKSPACE}/services/worker/compose.yaml" ]
}

@test "workspace: compose.yaml lists both services" {
  grep -Fq '  api:' "${WORKSPACE}/compose.yaml"
  grep -Fq '  worker:' "${WORKSPACE}/compose.yaml"
}

# ---- API service tests ----

@test "workspace: api GET /health returns status ok" {
  run curl -sf "http://localhost:${API_PORT}/health"
  assert_success
  assert_output --partial '"status"'
  assert_output --partial '"ok"'
}

@test "workspace: api GET /docs returns Swagger UI" {
  run curl -sf "http://localhost:${API_PORT}/docs"
  assert_success
  assert_output --partial "swagger"
}

# ---- Worker service tests ----

@test "workspace: worker GET /health returns status ok" {
  run curl -sf "http://localhost:${WORKER_PORT}/health"
  assert_success
  assert_output --partial '"status"'
  assert_output --partial '"ok"'
}

# ---- Infrastructure tests ----

@test "workspace: postgres service running" {
  run docker compose -f "${WORKSPACE}/compose.yaml" ps --format json
  assert_output --partial "postgres"
}

@test "workspace: compose.yaml valid (config check)" {
  run docker compose -f "${WORKSPACE}/compose.yaml" config --quiet
  assert_success
}

@test "workspace: shared network exists" {
  local net_name
  net_name="$(grep 'name:' "${WORKSPACE}/compose.yaml" | head -n1 | awk '{print $2}')"
  assert [ -n "$net_name" ]
  run docker network inspect "$net_name"
  assert_success
}

# ---- Non-root tests ----

@test "workspace: api container is running" {
  run docker compose -f "${WORKSPACE}/compose.yaml" exec -T api python -c "import sys; print(sys.version)"
  assert_success
  assert_output --partial "3.12"
}
