#!/usr/bin/env bats
# tests/integration/layer_shared/test_layer_trivy.bats

setup() {
  load '../../helpers/layer_test_helper'
  _common_setup
  PROJECT="$(setup_project_scaffold "testapp")"
  source_layer "${REPO_ROOT}/lib/layers/shared/trivy.sh"
}

teardown() {
  _common_teardown
}

@test "layer_trivy: .trivyignore created" {
  apply_layer_trivy "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -f "${PROJECT}/.trivyignore" ]
}

@test "layer_trivy: VS Code extension injected" {
  apply_layer_trivy "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -q "trivy\|aqua" "${PROJECT}/.devcontainer/devcontainer.json"
}

@test "layer_trivy: idempotent" {
  apply_layer_trivy "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local snap1="${TEST_TEMP}/snap1"
  cat "${PROJECT}/.trivyignore" > "$snap1"
  apply_layer_trivy "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  diff "$snap1" "${PROJECT}/.trivyignore"
}
