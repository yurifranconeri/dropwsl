#!/usr/bin/env bash
# lib/layers/shared/agent-developer.sh — Layer: @developer agent (AI-Powered Dev)
# Composes .github/ structure with agents, instructions, knowledge, skills, prompts, hooks.
# Cross-language: content comes from templates/agents/ (3-tier: global → <lang> → layers).
# MUST run AFTER all other layers (needs to inspect the project to detect applied layers).

[[ -n "${_AGENT_DEVELOPER_SH_LOADED:-}" ]] && return 0
_AGENT_DEVELOPER_SH_LOADED=1

_LAYER_PHASE="agents"
_LAYER_CONFLICTS=""
_LAYER_REQUIRES=""

# shellcheck source=lib/layers/shared/agent-helpers.sh
source "${BASH_SOURCE[0]%/*}/agent-helpers.sh"

apply_layer_agent_developer() {
  local project_path="$1"
  local name="${2:-}"
  local lang="${3:-python}"

  log "Applying layer: agent-developer (AI-Powered Dev)"

  if ! _resolve_agents_base; then
    warn "templates/agents not found -- agent-developer not applied"
    return 1
  fi

  local global_dir="${AGENTS_BASE}/global"
  local lang_dir="${AGENTS_BASE}/${lang}"
  local layers_dir="${AGENTS_BASE}/layers"

  mkdir -p "${project_path}/.github/agents"
  mkdir -p "${project_path}/.github/instructions"
  mkdir -p "${project_path}/.github/knowledge"
  mkdir -p "${project_path}/.github/skills"
  mkdir -p "${project_path}/.github/prompts"

  # ---- 1. Detect applied layers ----
  local -a applied_layers=()
  if [[ -d "$layers_dir" ]]; then
    local layer_d layer_name
    for layer_d in "$layers_dir"/*/; do
      [[ -d "$layer_d" ]] || continue
      layer_name="$(basename "$layer_d")"
      if [[ -f "${layer_d}/detect.sh" ]]; then
        if bash "${layer_d}/detect.sh" "$project_path" 2>/dev/null; then
          applied_layers+=("$layer_name")
        fi
      fi
    done
  fi

  # ---- 2. Compose developer.agent.md (global base + lang additions + knowledge refs) ----
  local agent_out="${project_path}/.github/agents/developer.agent.md"
  if [[ ! -f "$agent_out" ]]; then
    # Global base (has frontmatter)
    if [[ -f "${global_dir}/agents/developer.agent.md" ]]; then
      cat "${global_dir}/agents/developer.agent.md" > "$agent_out"
    fi
    # Lang additions (no frontmatter, appended)
    if [[ -f "${lang_dir}/agents/developer.agent.md" ]]; then
      echo "" >> "$agent_out"
      cat "${lang_dir}/agents/developer.agent.md" >> "$agent_out"
    fi
    # Dynamic: Knowledge file references
    echo "" >> "$agent_out"
    echo "## Knowledge files" >> "$agent_out"
    echo "" >> "$agent_out"
    echo "Read and follow these for domain-specific guidance:" >> "$agent_out"
    echo "" >> "$agent_out"
  fi

  # ---- 3. Copy knowledge files (developer namespace: global → lang → layers) ----
  _copy_files_noclobber "${global_dir}/knowledge/developer" "${project_path}/.github/knowledge/developer"
  _copy_files_noclobber "${lang_dir}/knowledge/developer" "${project_path}/.github/knowledge/developer"
  local layer
  for layer in "${applied_layers[@]}"; do
    _copy_files_noclobber "${layers_dir}/${layer}/knowledge" "${project_path}/.github/knowledge/developer"
  done

  # Add knowledge refs to agent.md
  if [[ -f "$agent_out" ]]; then
    local f
    for f in "${project_path}/.github/knowledge/developer"/*.md; do
      [[ -f "$f" ]] || continue
      local ref=".github/knowledge/developer/$(basename "$f")"
      if ! grep -Fq "$ref" "$agent_out" 2>/dev/null; then
        echo "- \`${ref}\`" >> "$agent_out"
      fi
    done
  fi

  # ---- 3b. Copy shared knowledge (accessible to all agents) ----
  _copy_shared_knowledge "${global_dir}" "${lang_dir}" "${project_path}"

  # ---- 4. Copy instructions (global → lang → layers) ----
  _copy_files_noclobber "${global_dir}/instructions" "${project_path}/.github/instructions"
  _copy_files_noclobber "${lang_dir}/instructions" "${project_path}/.github/instructions"
  for layer in "${applied_layers[@]}"; do
    _copy_files_noclobber "${layers_dir}/${layer}/instructions" "${project_path}/.github/instructions"
  done

  # ---- 5. Compose skills (flat, prefix-filtered: global base + lang additions) ----
  _copy_skills "${global_dir}/skills" "${project_path}/.github/skills" "developer-"
  _compose_skills "${lang_dir}/skills" "${project_path}/.github/skills" "developer-"

  # ---- 6. Copy prompts (flat, prefix-filtered: global → lang → layers) ----
  _copy_prompts_by_prefix "${global_dir}/prompts" "${project_path}/.github/prompts" "developer-"
  _copy_prompts_by_prefix "${lang_dir}/prompts" "${project_path}/.github/prompts" "developer-"
  for layer in "${applied_layers[@]}"; do
    _copy_prompts_by_prefix "${layers_dir}/${layer}/prompts" "${project_path}/.github/prompts" "dev-"
  done

  # ---- 7. Compose copilot-instructions.md (fragment-based, create-or-append) ----
  local instructions_out="${project_path}/.github/copilot-instructions.md"
  local agents_md="${project_path}/AGENTS.md"

  # Developer fragment
  local dev_fragment="${lang_dir}/copilot-instructions-fragments/developer.md"
  if [[ -f "$dev_fragment" ]]; then
    _append_section "$instructions_out" "## Stack" "$dev_fragment"
    _append_section "$agents_md" "## Stack" "$dev_fragment"
  fi

  # Layer fragments
  for layer in "${applied_layers[@]}"; do
    local fragment="${layers_dir}/${layer}/copilot-instructions-fragment.md"
    if [[ -f "$fragment" ]]; then
      local marker
      marker="$(grep -m1 '^## ' "$fragment" 2>/dev/null || echo "## ${layer}")"
      _append_section "$instructions_out" "$marker" "$fragment"
      _append_section "$agents_md" "$marker" "$fragment"
    fi
  done

  # Security tools section (dynamic, marker-based)
  local -a sec_tools=()
  for layer in "${applied_layers[@]}"; do
    case "$layer" in
      gitleaks) sec_tools+=("Gitleaks (pre-commit secret scanning)") ;;
      semgrep)  sec_tools+=("Semgrep (SAST)") ;;
      trivy)    sec_tools+=("Trivy (CVE scanning)") ;;
    esac
  done
  if (( ${#sec_tools[@]} > 0 )); then
    local sec_tmp
    sec_tmp="$(make_temp)"
    {
      echo "## Security tools"
      echo ""
      local st
      for st in "${sec_tools[@]}"; do
        echo "- ${st}"
      done
    } > "$sec_tmp"
    _append_section "$instructions_out" "## Security tools" "$sec_tmp"
    _append_section "$agents_md" "## Security tools" "$sec_tmp"
  fi

  # MCP servers section (dynamic, marker-based)
  if [[ -f "${project_path}/.vscode/mcp.json" ]]; then
    local servers
    servers="$(sed -n '/"servers"/,/^  }/{s/^    "\([a-z_-]*\)".*/\1/p}' "${project_path}/.vscode/mcp.json" 2>/dev/null | paste -sd', ')"
    if [[ -n "$servers" ]]; then
      local mcp_tmp
      mcp_tmp="$(make_temp)"
      {
        echo "## MCP servers"
        echo ""
        echo "- Available: ${servers}"
      } > "$mcp_tmp"
      _append_section "$instructions_out" "## MCP servers" "$mcp_tmp"
      _append_section "$agents_md" "## MCP servers" "$mcp_tmp"
    fi
  fi

  # ---- 8. Copy hooks to .vscode/ ----
  if [[ -f "${lang_dir}/hooks/copilot-hooks.json" ]]; then
    local hooks_out="${project_path}/.vscode/copilot-hooks.json"
    if [[ ! -f "$hooks_out" ]]; then
      mkdir -p "${project_path}/.vscode"
      cp "${lang_dir}/hooks/copilot-hooks.json" "$hooks_out"
    fi
  fi

  # ---- 9. Recompose isolation constraints for ALL agents ----
  _recompose_isolation_constraints "$project_path"

  echo "  Layer:    agent-developer (AI-Powered Dev -- @developer + instructions + knowledge + hooks)"
}
