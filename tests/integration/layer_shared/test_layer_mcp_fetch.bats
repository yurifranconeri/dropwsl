#!/usr/bin/env bats
# tests/integration/layer_shared/test_layer_mcp_fetch.bats

setup() {
  load '../../helpers/layer_test_helper'
  _common_setup
  PROJECT="$(setup_project_scaffold "testapp")"
  source_layer "${REPO_ROOT}/lib/layers/shared/mcp-fetch.sh"
}

teardown() {
  _common_teardown
}

@test "layer_mcp_fetch: .vscode/mcp.json created with server" {
  apply_layer_mcp_fetch "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -f "${PROJECT}/.vscode/mcp.json" ]
  grep -Fq "fetch" "${PROJECT}/.vscode/mcp.json"
}

@test "layer_mcp_fetch: idempotent" {
  apply_layer_mcp_fetch "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local snap1="${TEST_TEMP}/snap1"
  cat "${PROJECT}/.vscode/mcp.json" > "$snap1"
  apply_layer_mcp_fetch "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  diff "$snap1" "${PROJECT}/.vscode/mcp.json"
}
