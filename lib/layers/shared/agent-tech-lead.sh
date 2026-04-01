#!/usr/bin/env bash
# lib/layers/shared/agent-tech-lead.sh — Layer: @tech-lead agent (AI-Powered Dev)
# Composes .github/ structure with Tech Lead agent, knowledge, skills, prompts.
# Cross-language: content comes from templates/agents/ (3-tier: global → <lang>).

[[ -n "${_AGENT_TECH_LEAD_SH_LOADED:-}" ]] && return 0
_AGENT_TECH_LEAD_SH_LOADED=1

_LAYER_PHASE="agents"
_LAYER_CONFLICTS=""
_LAYER_REQUIRES=""

# shellcheck source=lib/layers/shared/agent-helpers.sh
source "${BASH_SOURCE[0]%/*}/agent-helpers.sh"

apply_layer_agent_tech_lead() {
  _apply_content_agent_layer "$1" "${2:-}" "${3:-python}" \
    "tech-lead" "tech-lead" "tech-lead.md" "## Architecture" "agent-tech-lead" || return 0
}
