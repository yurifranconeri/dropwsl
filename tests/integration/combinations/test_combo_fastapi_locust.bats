#!/usr/bin/env bats
# tests/integration/combinations/test_combo_fastapi_locust.bats
# Validates: fastapi + compose + locust generate compose with app + locust services,
# .env.example with LOCUST_HOST, locustfile.py present.

setup() {
  load '../../helpers/layer_test_helper'
  _common_setup
  PROJECT="$(setup_project_scaffold "testapp")"
  source_layer "${REPO_ROOT}/lib/layers/python/fastapi.sh"
  source_layer "${REPO_ROOT}/lib/layers/shared/compose.sh"
  source_layer "${REPO_ROOT}/lib/layers/python/locust.sh"
}

teardown() {
  _common_teardown
}

@test "combo fastapi+compose+locust: all artifacts present" {
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_compose "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_locust "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"

  # FastAPI main.py
  grep -Fq "from fastapi" "${PROJECT}/main.py"
  # compose.yaml
  assert [ -f "${PROJECT}/compose.yaml" ]
  # locustfile.py
  assert [ -f "${PROJECT}/locustfile.py" ]
  # .env.example
  assert [ -f "${PROJECT}/.env.example" ]
}

@test "combo fastapi+compose+locust: compose has app and locust services" {
  apply_layer_compose "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_locust "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"

  grep -Fq '  app:' "${PROJECT}/compose.yaml"
  grep -Fq '  locust:' "${PROJECT}/compose.yaml"
}

@test "combo fastapi+compose+locust: .env.example has LOCUST_HOST" {
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_compose "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_locust "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"

  grep -Fq 'LOCUST_HOST' "${PROJECT}/.env.example"
}

@test "combo fastapi+compose+locust: locust service uses official image" {
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_compose "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_locust "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"

  grep -Fq 'locustio/locust' "${PROJECT}/compose.yaml"
}

@test "combo fastapi+compose+locust: locustfile.py tests /health and /" {
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_compose "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_locust "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"

  grep -Fq '/health' "${PROJECT}/locustfile.py"
  grep -Fq '"/"' "${PROJECT}/locustfile.py"
}

@test "combo fastapi+compose+locust: locust does not mutate Dockerfile" {
  # Save Dockerfile state before locust
  apply_layer_compose "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local before
  before="$(cat "${PROJECT}/Dockerfile")"

  apply_layer_locust "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"

  local after
  after="$(cat "${PROJECT}/Dockerfile")"
  [[ "$before" == "$after" ]]
}

@test "combo fastapi+compose+locust: locust deps in requirements-dev.txt (not prod)" {
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_compose "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_locust "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"

  grep -Fq 'locust' "${PROJECT}/requirements-dev.txt"
  # locust should NOT be in requirements.txt (prod)
  ! grep -Fq 'locust' "${PROJECT}/requirements.txt"
}
