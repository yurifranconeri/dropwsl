#!/usr/bin/env bats
# tests/integration/combinations/test_combo_src_fastapi_postgres_redis.bats

setup() {
  load '../../helpers/layer_test_helper'
  _common_setup
  PROJECT="$(setup_project_scaffold "testapp")"
  source_layer "${REPO_ROOT}/lib/layers/python/src.sh"
  source_layer "${REPO_ROOT}/lib/layers/python/fastapi.sh"
  source_layer "${REPO_ROOT}/lib/layers/shared/compose.sh"
  source_layer "${REPO_ROOT}/lib/layers/python/postgres.sh"
  source_layer "${REPO_ROOT}/lib/layers/python/redis.sh"
}

teardown() {
  _common_teardown
}

@test "combo src+fastapi+postgres+redis: all modules present" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_postgres "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_redis "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -d "${PROJECT}/src/testapp/db" ]
  assert [ -d "${PROJECT}/src/testapp/cache" ]
}

@test "combo src+fastapi+postgres+redis: compose with both services" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_compose "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_postgres "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_redis "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "postgres" "${PROJECT}/compose.yaml"
  grep -Fq "redis" "${PROJECT}/compose.yaml"
}

@test "combo src+fastapi+postgres+redis: pytest_plugins has db and cache" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_compose "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_postgres "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_redis "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local conftest="${PROJECT}/tests/conftest.py"
  grep -Fq 'tests.fixtures.db' "$conftest"
  grep -Fq 'tests.fixtures.cache' "$conftest"
}

@test "combo src+fastapi+postgres+redis: imports precede pytest_plugins in conftest" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_compose "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_postgres "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_redis "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local conftest="${PROJECT}/tests/conftest.py"
  # All import/from lines must appear before pytest_plugins
  local last_import_line plugins_line
  last_import_line="$(grep -nE '^(import |from )' "$conftest" | tail -n1 | cut -d: -f1)"
  plugins_line="$(grep -n 'pytest_plugins' "$conftest" | head -n1 | cut -d: -f1)"
  assert [ -n "$last_import_line" ]
  assert [ -n "$plugins_line" ]
  assert [ "$last_import_line" -lt "$plugins_line" ]
}

@test "combo src+fastapi+postgres+redis: health includes postgres and redis" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_postgres "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_redis "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq 'health_status["postgres"] = "ok" if postgres_ok else "degraded"' "${PROJECT}/src/testapp/main.py"
  grep -Fq 'health_status["redis"] = "ok" if redis_ok else "degraded"' "${PROJECT}/src/testapp/main.py"
  grep -Fxq '    return health_status' "${PROJECT}/src/testapp/main.py"
}
