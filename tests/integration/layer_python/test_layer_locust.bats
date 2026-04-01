#!/usr/bin/env bats
# tests/integration/layer_python/test_layer_locust.bats

setup() {
  load '../../helpers/layer_test_helper'
  _common_setup
  PROJECT="$(setup_project_scaffold "testapp")"
  source_layer "${REPO_ROOT}/lib/layers/python/locust.sh"
}

teardown() {
  _common_teardown
}

@test "layer_locust: locustfile.py created" {
  apply_layer_locust "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -f "${PROJECT}/locustfile.py" ]
}

@test "layer_locust: requirements-dev.txt contains locust (always)" {
  apply_layer_locust "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "locust" "${PROJECT}/requirements-dev.txt"
}

@test "layer_locust: locustfile.py has /health and /" {
  apply_layer_locust "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "/health" "${PROJECT}/locustfile.py"
  grep -Fq 'self.client.get("/")' "${PROJECT}/locustfile.py"
}

@test "layer_locust: locustfile.py uses LOCUST_HOST env" {
  apply_layer_locust "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "LOCUST_HOST" "${PROJECT}/locustfile.py"
}

@test "layer_locust: compose service locust injected" {
  # Create skeleton compose.yaml (simulates compose layer)
  cat > "${PROJECT}/compose.yaml" <<'YAML'
services: {}

networks:
  default:
    name: testapp-net
YAML
  apply_layer_locust "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "locust:" "${PROJECT}/compose.yaml"
  grep -Fq "locustio/locust" "${PROJECT}/compose.yaml"
  grep -Fq "8089:8089" "${PROJECT}/compose.yaml"
}

@test "layer_locust: compose service mounts locustfile.py" {
  cat > "${PROJECT}/compose.yaml" <<'YAML'
services: {}

networks:
  default:
    name: testapp-net
YAML
  apply_layer_locust "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "locustfile.py:/mnt/locust/locustfile.py" "${PROJECT}/compose.yaml"
}

@test "layer_locust: without compose.yaml does not inject service" {
  rm -f "${PROJECT}/compose.yaml"
  apply_layer_locust "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ ! -f "${PROJECT}/compose.yaml" ]
}

@test "layer_locust: .env.example receives LOCUST_HOST" {
  # Create .env.example (simulates compose layer or scaffold)
  echo '# Variaveis de ambiente' > "${PROJECT}/.env.example"
  apply_layer_locust "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "LOCUST_HOST" "${PROJECT}/.env.example"
}

@test "layer_locust: README does not show compose command" {
  cat > "${PROJECT}/README.md" <<'MD'
# testapp

## Docker
MD
  apply_layer_locust "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  ! grep -Fq 'docker compose up locust' "${PROJECT}/README.md"
}

@test "layer_locust: README shows --host" {
  cat > "${PROJECT}/README.md" <<'MD'
# testapp

## Docker
MD
  apply_layer_locust "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq -- '--host' "${PROJECT}/README.md"
}

@test "layer_locust: Dockerfile is NOT modified" {
  local before
  before="$(cat "${PROJECT}/.devcontainer/Dockerfile")"
  apply_layer_locust "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local after
  after="$(cat "${PROJECT}/.devcontainer/Dockerfile")"
  [ "$before" = "$after" ]
}

@test "layer_locust: idempotent" {
  apply_layer_locust "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local snap1="${TEST_TEMP}/snap1"
  cat "${PROJECT}/locustfile.py" > "$snap1"
  apply_layer_locust "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  diff "$snap1" "${PROJECT}/locustfile.py"
}

@test "layer_locust: workspace mode — existing service becomes a locust runner" {
  cat > "${PROJECT}/compose.yaml" <<'YAML'
services:
  testapp:
    build:
      context: services/testapp
      dockerfile: ../../.devcontainer/testapp/Dockerfile
    volumes:
      - .:/workspaces/testws:cached
    working_dir: /workspaces/testws/services/testapp
    command: sleep infinity
    ports:
      - "8001:8000"

networks:
  default:
    name: ws-net
YAML
  DROPWSL_WORKSPACE="/tmp/fakews"
  apply_layer_locust "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  unset DROPWSL_WORKSPACE
  grep -Fq 'command: locust -f locustfile.py --web-host 0.0.0.0 --web-port 8089' "${PROJECT}/compose.yaml"
  grep -Fq '"8001:8089"' "${PROJECT}/compose.yaml"
  grep -Fq 'LOCUST_HOST: ${LOCUST_HOST:-http://target-service:8000}' "${PROJECT}/compose.yaml"
  ! grep -Fq 'locustio/locust' "${PROJECT}/compose.yaml"
}

@test "layer_locust: workspace mode — missing environment stays non-fatal under strict mode" {
  cat > "${PROJECT}/compose.yaml" <<'YAML'
services:
  testapp:
    build:
      context: services/testapp
      dockerfile: ../../.devcontainer/testapp/Dockerfile
    volumes:
      - .:/workspaces/testws:cached
    working_dir: /workspaces/testws/services/testapp
    command: sleep infinity
    ports:
      - "8001:8000"

networks:
  default:
    name: ws-net
YAML
  (
    set -euo pipefail
    DROPWSL_WORKSPACE="/tmp/fakews"
    apply_layer_locust "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  )
  grep -Fq 'command: locust -f locustfile.py --web-host 0.0.0.0 --web-port 8089' "${PROJECT}/compose.yaml"
  grep -Fq 'LOCUST_HOST: ${LOCUST_HOST:-http://target-service:8000}' "${PROJECT}/compose.yaml"
}

@test "layer_locust: workspace mode — service named locust is not duplicated" {
  cat > "${PROJECT}/compose.yaml" <<'YAML'
services:
  locust:
    build:
      context: services/locust
      dockerfile: ../../.devcontainer/locust/Dockerfile
    volumes:
      - .:/workspaces/testws:cached
    working_dir: /workspaces/testws/services/locust
    command: sleep infinity
    ports:
      - "8001:8000"

networks:
  default:
    name: ws-net
YAML
  DROPWSL_WORKSPACE="/tmp/fakews"
  apply_layer_locust "$PROJECT" "locust" "python" "${PROJECT}/.devcontainer"
  unset DROPWSL_WORKSPACE
  run grep -c '^  locust:$' "${PROJECT}/compose.yaml"
  assert_success
  assert_output '1'
  grep -Fq 'command: locust -f locustfile.py --web-host 0.0.0.0 --web-port 8089' "${PROJECT}/compose.yaml"
  ! grep -Fq 'locustio/locust' "${PROJECT}/compose.yaml"
}

@test "layer_locust: workspace mode — .env.example gets explicit target placeholder" {
  echo '# Variaveis de ambiente' > "${PROJECT}/.env.example"
  DROPWSL_WORKSPACE="/tmp/fakews"
  apply_layer_locust "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  unset DROPWSL_WORKSPACE
  grep -Fq 'LOCUST_HOST=http://target-service:8000' "${PROJECT}/.env.example"
}

@test "layer_locust: with FastAPI present — deps still go to requirements-dev" {
  source_layer "${REPO_ROOT}/lib/layers/python/fastapi.sh"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_locust "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "locust" "${PROJECT}/requirements-dev.txt"
}
