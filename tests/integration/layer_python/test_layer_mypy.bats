#!/usr/bin/env bats
# tests/integration/layer_python/test_layer_mypy.bats

setup() {
  load '../../helpers/layer_test_helper'
  _common_setup
  PROJECT="$(setup_project_scaffold "testapp")"
  source_layer "${REPO_ROOT}/lib/layers/python/mypy.sh"
}

teardown() {
  _common_teardown
}

@test "layer_mypy: requirements-dev.txt contains mypy" {
  apply_layer_mypy "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "mypy" "${PROJECT}/requirements-dev.txt"
}

@test "layer_mypy: pyproject.toml contains [tool.mypy]" {
  apply_layer_mypy "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "[tool.mypy]" "${PROJECT}/pyproject.toml"
}

@test "layer_mypy: post-create.sh contains mypy check" {
  apply_layer_mypy "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -q "mypy" "${PROJECT}/.devcontainer/post-create.sh"
}

@test "layer_mypy: devcontainer.json with Pylance type checking" {
  apply_layer_mypy "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -q "typeCheckingMode\|pylance\|Pylance" "${PROJECT}/.devcontainer/devcontainer.json" 2>/dev/null || \
  grep -q "vscode-pylance" "${PROJECT}/.devcontainer/devcontainer.json" 2>/dev/null || true
}

@test "layer_mypy: idempotent — [tool.mypy] already exists → no duplication" {
  apply_layer_mypy "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local count_before
  count_before=$(grep -c "\\[tool.mypy\\]" "${PROJECT}/pyproject.toml" || true)
  apply_layer_mypy "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local count_after
  count_after=$(grep -c "\\[tool.mypy\\]" "${PROJECT}/pyproject.toml" || true)
  assert [ "$count_before" -eq "$count_after" ]
}
