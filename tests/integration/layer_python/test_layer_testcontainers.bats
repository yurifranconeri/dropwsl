#!/usr/bin/env bats
# tests/integration/layer_python/test_layer_testcontainers.bats

setup() {
  load '../../helpers/layer_test_helper'
  _common_setup
  PROJECT="$(setup_project_scaffold "testapp")"
  # Testcontainers requer src + postgres
  source_layer "${REPO_ROOT}/lib/layers/python/src.sh"
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  source_layer "${REPO_ROOT}/lib/layers/python/postgres.sh"
  apply_layer_postgres "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  source_layer "${REPO_ROOT}/lib/layers/python/testcontainers.sh"
}

teardown() {
  _common_teardown
}

@test "layer_testcontainers: requirements-dev.txt contains testcontainers" {
  apply_layer_testcontainers "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "testcontainers" "${PROJECT}/requirements-dev.txt"
}

@test "layer_testcontainers: pyproject.toml contains integration marker" {
  apply_layer_testcontainers "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -q "integration" "${PROJECT}/pyproject.toml"
}

@test "layer_testcontainers: tests/integration/conftest.py created" {
  apply_layer_testcontainers "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -f "${PROJECT}/tests/integration/conftest.py" ]
  grep -q "testcontainers\|PostgresContainer" "${PROJECT}/tests/integration/conftest.py"
}

@test "layer_testcontainers: tests/integration/test_integration.py created" {
  apply_layer_testcontainers "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -f "${PROJECT}/tests/integration/test_integration.py" ]
}

@test "layer_testcontainers: tests/smoke/test_smoke.py created" {
  apply_layer_testcontainers "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -f "${PROJECT}/tests/smoke/test_smoke.py" ]
  assert [ -f "${PROJECT}/tests/smoke/__init__.py" ]
}

@test "layer_testcontainers: idempotent" {
  apply_layer_testcontainers "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local snap1="${TEST_TEMP}/snap1"
  cat "${PROJECT}/tests/integration/conftest.py" > "$snap1"
  apply_layer_testcontainers "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  diff "$snap1" "${PROJECT}/tests/integration/conftest.py"
}
