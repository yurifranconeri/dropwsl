#!/usr/bin/env bats
# tests/integration/test_workspace.bats — Tests for workspace_init, workspace_devcontainer, workspace_compose_service

setup() {
  load '../helpers/layer_test_helper'
  _common_setup
  activate_mocks
}

teardown() {
  _common_teardown
}

@test "workspace_init: creates structure" {
  local ws="${TEST_TEMP}/myworkspace"
  workspace_init "$ws" "myworkspace"
  assert [ -d "${ws}/services" ]
  assert [ -d "${ws}/.devcontainer" ]
  assert [ -f "${ws}/compose.yaml" ]
  assert [ -f "${ws}/.env" ]
  assert [ -f "${ws}/.gitignore" ]
  assert [ -f "${ws}/README.md" ]
}

@test "workspace_init: idempotent" {
  local ws="${TEST_TEMP}/myworkspace"
  workspace_init "$ws" "myworkspace"
  local before
  before="$(cat "${ws}/compose.yaml")"
  workspace_init "$ws" "myworkspace"
  local after
  after="$(cat "${ws}/compose.yaml")"
  assert [ "$before" = "$after" ]
}

@test "workspace_devcontainer: generates devcontainer for service" {
  local ws="${TEST_TEMP}/myworkspace"
  workspace_init "$ws" "myworkspace"
  workspace_devcontainer "$ws" "api" "myworkspace" "python"
  assert [ -f "${ws}/.devcontainer/api/devcontainer.json" ]
  assert [ -f "${ws}/.devcontainer/api/Dockerfile" ]
}

@test "workspace_devcontainer: base extensions without deprecated" {
  local ws="${TEST_TEMP}/myworkspace"
  workspace_init "$ws" "myworkspace"
  workspace_devcontainer "$ws" "api" "myworkspace" "python"
  local dc="${ws}/.devcontainer/api/devcontainer.json"
  grep -Fq 'ms-python.python' "$dc"
  grep -Fq 'GitHub.copilot-chat' "$dc"
  # Deprecated/redundant should not be present
  run grep -F '"GitHub.copilot"' "$dc"
  assert_failure
  run grep -F 'ms-python.debugpy' "$dc"
  assert_failure
}

@test "workspace_compose_service: injects service into compose" {
  local ws="${TEST_TEMP}/myworkspace"
  workspace_init "$ws" "myworkspace"
  workspace_compose_service "$ws" "api" "myworkspace" "8001"
  grep -Fq "api:" "${ws}/compose.yaml"
}

@test "workspace_compose_service: service has env_file" {
  local ws="${TEST_TEMP}/myworkspace"
  workspace_init "$ws" "myworkspace"
  workspace_compose_service "$ws" "api" "myworkspace" "8001"
  grep -Fq "env_file: .env" "${ws}/compose.yaml"
}

@test "workspace_next_port: increments per service" {
  local ws="${TEST_TEMP}/myworkspace"
  workspace_init "$ws" "myworkspace"
  local port1
  port1="$(_workspace_next_port "$ws")"
  mkdir -p "${ws}/services/svc1"
  local port2
  port2="$(_workspace_next_port "$ws")"
  assert [ "$port1" != "$port2" ]
}
