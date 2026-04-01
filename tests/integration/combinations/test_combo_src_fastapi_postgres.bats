#!/usr/bin/env bats
# tests/integration/combinations/test_combo_src_fastapi_postgres.bats

setup() {
  load '../../helpers/layer_test_helper'
  _common_setup
  PROJECT="$(setup_project_scaffold "testapp")"
  source_layer "${REPO_ROOT}/lib/layers/python/src.sh"
  source_layer "${REPO_ROOT}/lib/layers/python/fastapi.sh"
  source_layer "${REPO_ROOT}/lib/layers/shared/compose.sh"
  source_layer "${REPO_ROOT}/lib/layers/python/postgres.sh"
}

teardown() {
  _common_teardown
}

@test "combo src+fastapi+postgres: DB engine with FastAPI" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_compose "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_postgres "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -q "create_engine\|get_session" "${PROJECT}/src/testapp/db/engine.py"
}

@test "combo src+fastapi+postgres: compose with postgres" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_compose "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_postgres "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "postgres" "${PROJECT}/compose.yaml"
}

@test "combo src+fastapi+postgres: all files are present" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_compose "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_postgres "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -f "${PROJECT}/src/testapp/main.py" ]
  assert [ -d "${PROJECT}/src/testapp/db" ]
  assert [ -f "${PROJECT}/compose.yaml" ]
  assert [ -f "${PROJECT}/.env.example" ]
}

@test "combo src+fastapi+postgres: health includes postgres status" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_postgres "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq 'health_status["postgres"] = "ok" if postgres_ok else "degraded"' "${PROJECT}/src/testapp/main.py"
}
