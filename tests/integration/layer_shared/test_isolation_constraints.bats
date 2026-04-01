#!/usr/bin/env bats
# tests/integration/layer_shared/test_isolation_constraints.bats
# Validates: isolation constraints are dynamically generated for all agents.
# Bug #83 from AUDIT: constraints were only generated with agent-developer.

setup() {
  load '../../helpers/layer_test_helper'
  _common_setup
  PROJECT="$(setup_project_scaffold "testapp")"
  source_layer "${REPO_ROOT}/lib/layers/shared/agent-po.sh"
  source_layer "${REPO_ROOT}/lib/layers/shared/agent-qa.sh"
  source_layer "${REPO_ROOT}/lib/layers/shared/agent-developer.sh"
}

teardown() {
  _common_teardown
}

# ── Single agent: no isolation rules ─────────────────────────────

@test "isolation: single agent does not get isolation rules" {
  apply_layer_agent_po "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  ! grep -q "## Isolation Rules" "${PROJECT}/.github/agents/po.agent.md"
}

# ── Two agents: both get isolation rules ─────────────────────────

@test "isolation: two agents both get isolation rules" {
  apply_layer_agent_po "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_agent_qa "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"

  grep -q "## Isolation Rules" "${PROJECT}/.github/agents/po.agent.md"
  grep -q "## Isolation Rules" "${PROJECT}/.github/agents/qa-lead.agent.md"
}

@test "isolation: po references qa-lead in redirect" {
  apply_layer_agent_po "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_agent_qa "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"

  grep -q "@qa-lead" "${PROJECT}/.github/agents/po.agent.md"
}

@test "isolation: qa-lead references po in redirect" {
  apply_layer_agent_po "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_agent_qa "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"

  grep -q "@po" "${PROJECT}/.github/agents/qa-lead.agent.md"
}

# ── Three agents: constraints updated for all ────────────────────

@test "isolation: third agent triggers recompose for all three" {
  apply_layer_agent_po "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_agent_qa "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_agent_developer "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"

  # All three should have isolation rules
  grep -q "## Isolation Rules" "${PROJECT}/.github/agents/po.agent.md"
  grep -q "## Isolation Rules" "${PROJECT}/.github/agents/qa-lead.agent.md"
  grep -q "## Isolation Rules" "${PROJECT}/.github/agents/developer.agent.md"

  # po should now reference both qa-lead and developer
  grep -q "@qa-lead" "${PROJECT}/.github/agents/po.agent.md"
  grep -q "@developer" "${PROJECT}/.github/agents/po.agent.md"
}

@test "isolation: developer uses 'developer- or dev-' prefix" {
  apply_layer_agent_po "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_agent_developer "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"

  grep -Fq 'developer-' "${PROJECT}/.github/agents/developer.agent.md"
  grep -Fq 'dev-' "${PROJECT}/.github/agents/developer.agent.md"
}

@test "isolation: po uses 'po-' prefix" {
  apply_layer_agent_po "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_agent_developer "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"

  grep -q '`po-`' "${PROJECT}/.github/agents/po.agent.md"
}

# ── Idempotency: recompose does not duplicate ────────────────────

@test "isolation: recompose is idempotent (no duplicate sections)" {
  apply_layer_agent_po "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_agent_qa "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"

  # Run again — should not duplicate
  apply_layer_agent_po "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_agent_qa "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"

  local count
  count="$(grep -c '## Isolation Rules' "${PROJECT}/.github/agents/po.agent.md")"
  [[ "$count" -eq 1 ]]

  count="$(grep -c '## Isolation Rules' "${PROJECT}/.github/agents/qa-lead.agent.md")"
  [[ "$count" -eq 1 ]]
}
