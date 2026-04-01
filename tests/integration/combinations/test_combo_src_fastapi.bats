#!/usr/bin/env bats
# tests/integration/combinations/test_combo_src_fastapi.bats

setup() {
  load '../../helpers/layer_test_helper'
  _common_setup
  PROJECT="$(setup_project_scaffold "testapp")"
  source_layer "${REPO_ROOT}/lib/layers/python/src.sh"
  source_layer "${REPO_ROOT}/lib/layers/python/fastapi.sh"
}

teardown() {
  _common_teardown
}

@test "combo src+fastapi: FastAPI em src/{pkg}/main.py" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "from fastapi" "${PROJECT}/src/testapp/main.py"
}

@test "combo src+fastapi: Dockerfile imports correct" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -q "src/" "${PROJECT}/Dockerfile"
}

@test "combo src+fastapi: conftest uses package import" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  # conftest.py has import from package (via fragment)
  grep -q "testapp" "${PROJECT}/tests/conftest.py"
}
