#!/usr/bin/env bats
# tests/integration/layer_python/test_layer_src.bats

setup() {
  load '../../helpers/layer_test_helper'
  _common_setup
  PROJECT="$(setup_project_scaffold "testapp")"
  source_layer "${REPO_ROOT}/lib/layers/python/src.sh"
}

teardown() {
  _common_teardown
}

@test "layer_src: creates src/{pkg}/ directory" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -d "${PROJECT}/src/testapp" ]
}

@test "layer_src: moves main.py to src/{pkg}/main.py" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -f "${PROJECT}/src/testapp/main.py" ]
}

@test "layer_src: creates __init__.py" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -f "${PROJECT}/src/testapp/__init__.py" ]
}

@test "layer_src: updates pyproject.toml with src layout" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -q 'pythonpath = \["src"\]\|\[project\.scripts\]' "${PROJECT}/pyproject.toml"
}

@test "layer_src: Dockerfile updated" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -q "src/" "${PROJECT}/Dockerfile"
}

@test "layer_src: idempotent — running 2x same result" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local snapshot1="${TEST_TEMP}/snap1"
  find "$PROJECT" -type f | sort | xargs md5sum > "$snapshot1" 2>/dev/null || true
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local snapshot2="${TEST_TEMP}/snap2"
  find "$PROJECT" -type f | sort | xargs md5sum > "$snapshot2" 2>/dev/null || true
  diff "$snapshot1" "$snapshot2"
}

@test "layer_src: no CRLF in generated files" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  ! grep -rP '\r' "${PROJECT}/src/" 2>/dev/null
}
