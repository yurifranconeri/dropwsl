#!/usr/bin/env bats
# tests/integration/layer_shared/test_layer_semgrep.bats

setup() {
  load '../../helpers/layer_test_helper'
  _common_setup
  PROJECT="$(setup_project_scaffold "testapp")"
  source_layer "${REPO_ROOT}/lib/layers/shared/semgrep.sh"
}

teardown() {
  _common_teardown
}

@test "layer_semgrep: .semgrep.yml created" {
  apply_layer_semgrep "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -f "${PROJECT}/.semgrep.yml" ]
}

@test "layer_semgrep: VS Code extension injected" {
  apply_layer_semgrep "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -q "semgrep" "${PROJECT}/.devcontainer/devcontainer.json"
}

@test "layer_semgrep: requirements-dev.txt contains semgrep" {
  apply_layer_semgrep "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "semgrep" "${PROJECT}/requirements-dev.txt"
}

@test "layer_semgrep: idempotent" {
  apply_layer_semgrep "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local snap1="${TEST_TEMP}/snap1"
  cat "${PROJECT}/.semgrep.yml" > "$snap1"
  apply_layer_semgrep "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  diff "$snap1" "${PROJECT}/.semgrep.yml"
}
