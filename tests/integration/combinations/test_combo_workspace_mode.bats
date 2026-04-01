#!/usr/bin/env bats
# tests/integration/combinations/test_combo_workspace_mode.bats
# Tests for new_project in workspace mode (multi-service via --service)

setup() {
  load '../../helpers/layer_test_helper'
  _common_setup
  activate_mocks
  export PROJECTS_DIR="${TEST_TEMP}/projects"
  mkdir -p "$PROJECTS_DIR"
  export NO_DEFAULTS=true
  export DEFAULT_LAYERS=()
  code() { :; }
  export -f code
  git() { command git "$@"; }
  export -f git
}

teardown() {
  _common_teardown
}

# ---- Workspace init ----

@test "workspace mode: creates workspace structure on first service" {
  new_project "myws" "python" "src,fastapi" "api" >&2
  assert [ -d "${PROJECTS_DIR}/myws/services" ]
  assert [ -d "${PROJECTS_DIR}/myws/.devcontainer" ]
  assert [ -f "${PROJECTS_DIR}/myws/compose.yaml" ]
  assert [ -f "${PROJECTS_DIR}/myws/.gitignore" ]
  assert [ -f "${PROJECTS_DIR}/myws/README.md" ]
}

# ---- Service structure ----

@test "workspace mode: service is in services/<name>/" {
  new_project "myws" "python" "src,fastapi" "api" >&2
  assert [ -d "${PROJECTS_DIR}/myws/services/api" ]
  assert [ -f "${PROJECTS_DIR}/myws/services/api/pyproject.toml" ]
}

@test "workspace mode: devcontainer is in .devcontainer/<service>/" {
  new_project "myws" "python" "src,fastapi" "api" >&2
  assert [ -f "${PROJECTS_DIR}/myws/.devcontainer/api/devcontainer.json" ]
  assert [ -f "${PROJECTS_DIR}/myws/.devcontainer/api/Dockerfile" ]
}

@test "workspace mode: devcontainer.json is compose-based" {
  new_project "myws" "python" "src,fastapi" "api" >&2
  grep -Fq "dockerComposeFile" "${PROJECTS_DIR}/myws/.devcontainer/api/devcontainer.json"
  grep -Fq '"service": "api"' "${PROJECTS_DIR}/myws/.devcontainer/api/devcontainer.json"
}

@test "workspace mode: service does not have its own .devcontainer/" {
  new_project "myws" "python" "src,fastapi" "api" >&2
  assert [ ! -d "${PROJECTS_DIR}/myws/services/api/.devcontainer" ]
}

@test "workspace mode: service does not have .git (git at root)" {
  new_project "myws" "python" "" "api" >&2
  assert [ ! -d "${PROJECTS_DIR}/myws/services/api/.git" ]
  assert [ -d "${PROJECTS_DIR}/myws/.git" ]
}

# ---- Compose ----

@test "workspace mode: compose.yaml has service entry" {
  new_project "myws" "python" "src,fastapi" "api" >&2
  grep -Fq "api:" "${PROJECTS_DIR}/myws/compose.yaml"
}

@test "workspace mode: explicit compose is preserved in summary" {
  run new_project "myws" "python" "src,fastapi,compose" "api"
  assert_success
  assert_output --partial "Layers:    src,fastapi,compose"
  assert [ -f "${PROJECTS_DIR}/myws/compose.yaml" ]
  assert [ ! -f "${PROJECTS_DIR}/myws/services/api/compose.yaml" ]
}

# ---- Multi-service ----

@test "workspace mode: second service adds to same workspace" {
  new_project "myws" "python" "src,fastapi" "api" >&2
  new_project "myws" "python" "src,fastapi" "worker" >&2
  assert [ -d "${PROJECTS_DIR}/myws/services/api" ]
  assert [ -d "${PROJECTS_DIR}/myws/services/worker" ]
  grep -Fq "api:" "${PROJECTS_DIR}/myws/compose.yaml"
  grep -Fq "worker:" "${PROJECTS_DIR}/myws/compose.yaml"
}

@test "workspace mode: second service has its own devcontainer" {
  new_project "myws" "python" "src" "svc1" >&2
  new_project "myws" "python" "src" "svc2" >&2
  assert [ -f "${PROJECTS_DIR}/myws/.devcontainer/svc1/devcontainer.json" ]
  assert [ -f "${PROJECTS_DIR}/myws/.devcontainer/svc2/devcontainer.json" ]
}

@test "workspace mode: ports increment per service" {
  new_project "myws" "python" "" "svc1" >&2
  new_project "myws" "python" "" "svc2" >&2
  local port1 port2
  port1="$(grep -A15 'svc1:' "${PROJECTS_DIR}/myws/compose.yaml" | grep -oP '\d+:8000' | head -1)"
  port2="$(grep -A15 'svc2:' "${PROJECTS_DIR}/myws/compose.yaml" | grep -oP '\d+:8000' | head -1)"
  assert [ "$port1" != "$port2" ]
}

# ---- Layers em workspace mode ----

@test "workspace mode: layers applied to service" {
  new_project "myws" "python" "src,fastapi" "api" >&2
  assert [ -d "${PROJECTS_DIR}/myws/services/api/src/api" ]
  grep -Fq "from fastapi" "${PROJECTS_DIR}/myws/services/api/src/api/main.py"
}

@test "workspace mode: .env.example merge at root" {
  new_project "myws" "python" "src,fastapi,postgres" "api" >&2
  grep -Fq "DATABASE_URL" "${PROJECTS_DIR}/myws/.env.example"
}

@test "workspace mode: postgres and redis without compose keep external provider" {
  new_project "myws" "python" "src,fastapi,postgres,redis" "api" >&2
  ! grep -Fq '  postgres:' "${PROJECTS_DIR}/myws/compose.yaml"
  ! grep -Fq '  redis:' "${PROJECTS_DIR}/myws/compose.yaml"
  grep -Fq 'user:pass@host:5432' "${PROJECTS_DIR}/myws/.env.example"
  grep -Fq 'redis://host:6379/0' "${PROJECTS_DIR}/myws/.env.example"
  grep -Fq 'RuntimeError' "${PROJECTS_DIR}/myws/services/api/src/api/db/engine.py"
  grep -Fq 'RuntimeError' "${PROJECTS_DIR}/myws/services/api/src/api/cache/client.py"
}

@test "workspace mode: explicit compose enables local postgres and redis" {
  new_project "myws" "python" "src,fastapi,postgres,redis,compose" "api" >&2
  grep -Fq '  postgres:' "${PROJECTS_DIR}/myws/compose.yaml"
  grep -Fq '  redis:' "${PROJECTS_DIR}/myws/compose.yaml"
  grep -Fq '@postgres:5432' "${PROJECTS_DIR}/myws/.env.example"
  grep -Fq 'redis://redis:6379/0' "${PROJECTS_DIR}/myws/.env.example"
  ! grep -Fq 'RuntimeError' "${PROJECTS_DIR}/myws/services/api/src/api/db/engine.py"
  ! grep -Fq 'RuntimeError' "${PROJECTS_DIR}/myws/services/api/src/api/cache/client.py"
}

@test "workspace mode: locust layer converts loadtest service into locust runner" {
  new_project "myws" "python" "locust" "loadtest" >&2
  assert [ -f "${PROJECTS_DIR}/myws/services/loadtest/locustfile.py" ]
  grep -Fq '  loadtest:' "${PROJECTS_DIR}/myws/compose.yaml"
  grep -Fq 'command: locust -f locustfile.py --web-host 0.0.0.0 --web-port 8089' "${PROJECTS_DIR}/myws/compose.yaml"
  grep -Fq ':8089"' "${PROJECTS_DIR}/myws/compose.yaml"
  grep -Fq 'LOCUST_HOST=http://target-service:8000' "${PROJECTS_DIR}/myws/.env.example"
  ! grep -Fq 'locustio/locust' "${PROJECTS_DIR}/myws/compose.yaml"
}

@test "workspace mode: service named locust stays single and runnable" {
  new_project "myws" "python" "locust" "locust" >&2
  run grep -c '^  locust:$' "${PROJECTS_DIR}/myws/compose.yaml"
  assert_success
  assert_output '1'
  grep -Fq 'command: locust -f locustfile.py --web-host 0.0.0.0 --web-port 8089' "${PROJECTS_DIR}/myws/compose.yaml"
  grep -Fq ':8089"' "${PROJECTS_DIR}/myws/compose.yaml"
  ! grep -Fq 'locustio/locust' "${PROJECTS_DIR}/myws/compose.yaml"
}
