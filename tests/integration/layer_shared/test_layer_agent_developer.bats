#!/usr/bin/env bats
# tests/integration/layer_shared/test_layer_agent_developer.bats

setup() {
  load '../../helpers/layer_test_helper'
  _common_setup
  PROJECT="$(setup_project_scaffold "testapp")"
  # Agent layers source agent-helpers internally
  source_layer "${REPO_ROOT}/lib/layers/shared/agent-developer.sh"
}

teardown() {
  _common_teardown
}

@test "layer_agent_developer: .github/agents/developer.agent.md created" {
  apply_layer_agent_developer "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -f "${PROJECT}/.github/agents/developer.agent.md" ]
}

@test "layer_agent_developer: copilot-instructions.md updated" {
  apply_layer_agent_developer "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -f "${PROJECT}/.github/copilot-instructions.md" ]
}

@test "layer_agent_developer: AGENTS.md created" {
  apply_layer_agent_developer "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -f "${PROJECT}/AGENTS.md" ]
}

@test "layer_agent_developer: idempotent" {
  apply_layer_agent_developer "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local snap1="${TEST_TEMP}/snap1"
  cat "${PROJECT}/.github/agents/developer.agent.md" > "$snap1"
  apply_layer_agent_developer "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  diff "$snap1" "${PROJECT}/.github/agents/developer.agent.md"
}
