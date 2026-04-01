#!/usr/bin/env bats
# tests/integration/layer_shared/test_layer_agent_po.bats

setup() {
  load '../../helpers/layer_test_helper'
  _common_setup
  PROJECT="$(setup_project_scaffold "testapp")"
  source_layer "${REPO_ROOT}/lib/layers/shared/agent-po.sh"
}

teardown() {
  _common_teardown
}

@test "layer_agent_po: .github/agents/po.agent.md created" {
  apply_layer_agent_po "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -f "${PROJECT}/.github/agents/po.agent.md" ]
}

@test "layer_agent_po: copilot-instructions.md updated" {
  apply_layer_agent_po "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -f "${PROJECT}/.github/copilot-instructions.md" ]
}

@test "layer_agent_po: prompts copied" {
  apply_layer_agent_po "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local count
  count=$(find "${PROJECT}/.github/prompts" -name "po-*" 2>/dev/null | wc -l)
  assert [ "$count" -gt 0 ]
}

@test "layer_agent_po: idempotent" {
  apply_layer_agent_po "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local snap1="${TEST_TEMP}/snap1"
  cat "${PROJECT}/.github/agents/po.agent.md" > "$snap1"
  apply_layer_agent_po "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  diff "$snap1" "${PROJECT}/.github/agents/po.agent.md"
}
