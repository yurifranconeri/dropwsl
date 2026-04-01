#!/usr/bin/env bats
# tests/unit/test_workspace_helpers.bats -- Tests for _workspace_next_port

setup() {
  load '../helpers/test_helper'
  _common_setup
  unset _WORKSPACE_SH_LOADED
  source "${REPO_ROOT}/lib/project/workspace.sh"
}

teardown() {
  _common_teardown
}

@test "workspace_next_port: 0 services → 8001" {
  local ws="${TEST_TEMP}/ws"
  mkdir -p "${ws}/.devcontainer"
  run _workspace_next_port "$ws"
  assert_success
  assert_output "8001"
}

@test "workspace_next_port: 2 services → 8003" {
  local ws="${TEST_TEMP}/ws"
  mkdir -p "${ws}/services/svc1" "${ws}/services/svc2"
  run _workspace_next_port "$ws"
  assert_success
  assert_output "8003"
}

