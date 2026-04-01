#!/usr/bin/env bats
# tests/integration/combinations/test_combo_src_fastapi_postgres_testcontainers.bats

setup() {
  load '../../helpers/layer_test_helper'
  _common_setup
  PROJECT="$(setup_project_scaffold "testapp")"
  source_layer "${REPO_ROOT}/lib/layers/python/src.sh"
  source_layer "${REPO_ROOT}/lib/layers/python/fastapi.sh"
  source_layer "${REPO_ROOT}/lib/layers/python/postgres.sh"
  source_layer "${REPO_ROOT}/lib/layers/python/testcontainers.sh"
}

teardown() {
  _common_teardown
}

@test "combo src+fastapi+postgres+testcontainers: conftest with fixtures" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_postgres "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_testcontainers "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -f "${PROJECT}/tests/integration/conftest.py" ]
  grep -q "PostgresContainer\|testcontainers" "${PROJECT}/tests/integration/conftest.py"
}

@test "combo src+fastapi+postgres+testcontainers: integration tests" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_postgres "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_testcontainers "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -f "${PROJECT}/tests/integration/test_integration.py" ]
}
