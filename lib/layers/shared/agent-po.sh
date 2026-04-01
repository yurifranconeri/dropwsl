#!/usr/bin/env bash
# lib/layers/shared/agent-po.sh — Layer: @po agent (AI-Powered Dev)
# Composes .github/ structure with PO agent, knowledge, skills, prompts.
# Cross-language: content comes from templates/agents/ (3-tier: global → <lang>).

[[ -n "${_AGENT_PO_SH_LOADED:-}" ]] && return 0
_AGENT_PO_SH_LOADED=1

_LAYER_PHASE="agents"
_LAYER_CONFLICTS=""
_LAYER_REQUIRES=""

# shellcheck source=lib/layers/shared/agent-helpers.sh
source "${BASH_SOURCE[0]%/*}/agent-helpers.sh"

apply_layer_agent_po() {
  _apply_content_agent_layer "$1" "${2:-}" "${3:-python}" \
    "po" "po" "po.md" "## Product" "agent-po" || return 0
}
