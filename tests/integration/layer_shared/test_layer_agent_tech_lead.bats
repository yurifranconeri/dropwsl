#!/usr/bin/env bats
# tests/integration/layer_shared/test_layer_agent_tech_lead.bats

setup() {
  load '../../helpers/layer_test_helper'
  _common_setup
  PROJECT="$(setup_project_scaffold "testapp")"
  source_layer "${REPO_ROOT}/lib/layers/shared/agent-tech-lead.sh"
}

teardown() {
  _common_teardown
}

@test "layer_agent_tech_lead: .github/agents/tech-lead.agent.md created" {
  apply_layer_agent_tech_lead "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -f "${PROJECT}/.github/agents/tech-lead.agent.md" ]
}

@test "layer_agent_tech_lead: prompts copied" {
  apply_layer_agent_tech_lead "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local count
  count=$(find "${PROJECT}/.github/prompts" -name "tech-lead-*" 2>/dev/null | wc -l)
  assert [ "$count" -gt 0 ]
}

@test "layer_agent_tech_lead: idempotent" {
  apply_layer_agent_tech_lead "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local snap1="${TEST_TEMP}/snap1"
  cat "${PROJECT}/.github/agents/tech-lead.agent.md" > "$snap1"
  apply_layer_agent_tech_lead "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  diff "$snap1" "${PROJECT}/.github/agents/tech-lead.agent.md"
}
