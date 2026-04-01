#!/usr/bin/env bats
# tests/integration/layer_shared/test_layer_mcp_docker.bats

setup() {
  load '../../helpers/layer_test_helper'
  _common_setup
  PROJECT="$(setup_project_scaffold "testapp")"
  source_layer "${REPO_ROOT}/lib/layers/shared/mcp-docker.sh"
}

teardown() {
  _common_teardown
}

@test "layer_mcp_docker: .vscode/mcp.json created with server" {
  apply_layer_mcp_docker "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -f "${PROJECT}/.vscode/mcp.json" ]
  grep -Fq "docker" "${PROJECT}/.vscode/mcp.json"
}

@test "layer_mcp_docker: idempotent" {
  apply_layer_mcp_docker "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local snap1="${TEST_TEMP}/snap1"
  cat "${PROJECT}/.vscode/mcp.json" > "$snap1"
  apply_layer_mcp_docker "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  diff "$snap1" "${PROJECT}/.vscode/mcp.json"
}
