#!/usr/bin/env bash
# lib/layers/shared/agent-qa.sh — Layer: @qa-lead agent (AI-Powered Dev)
# Composes .github/ structure with QA Lead agent, knowledge, skills, prompts.
# Cross-language: content comes from templates/agents/ (3-tier: global → <lang>).

[[ -n "${_AGENT_QA_SH_LOADED:-}" ]] && return 0
_AGENT_QA_SH_LOADED=1

_LAYER_PHASE="agents"
_LAYER_CONFLICTS=""
_LAYER_REQUIRES=""

# shellcheck source=lib/layers/shared/agent-helpers.sh
source "${BASH_SOURCE[0]%/*}/agent-helpers.sh"

apply_layer_agent_qa() {
  _apply_content_agent_layer "$1" "${2:-}" "${3:-python}" \
    "qa-lead" "qa-lead" "qa-lead.md" "## Quality" "agent-qa" || return 0
}
