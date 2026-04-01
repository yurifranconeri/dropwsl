#!/usr/bin/env bash
# lib/layers/shared/agent-helpers.sh — Shared helpers for agent composition layers.
# Not a layer itself (no apply_layer_ function). Sourced by agent-*.sh.

[[ -n "${_AGENT_HELPERS_SH_LOADED:-}" ]] && return 0
_AGENT_HELPERS_SH_LOADED=1

# Resolves the templates/agents/ base directory.
# Sets AGENTS_BASE variable. Returns 1 if not found.
_resolve_agents_base() {
  if [[ -d "${SCRIPT_DIR}/templates/agents" ]]; then
    AGENTS_BASE="${SCRIPT_DIR}/templates/agents"
  elif [[ -d "${INSTALL_DIR}/templates/agents" ]]; then
    AGENTS_BASE="${INSTALL_DIR}/templates/agents"
  else
    return 1
  fi
}

# Appends content from a file to a target, creating the target if needed.
# Idempotent: skips if marker string is already present in the target.
# Usage: _append_section <target_file> <marker_string> <content_file>
_append_section() {
  local target="$1" marker="$2" content_file="$3"
  [[ -f "$content_file" ]] || return 0
  if [[ ! -f "$target" ]]; then
    echo "# Project Instructions" > "$target"
    echo "" >> "$target"
  fi
  grep -qF "$marker" "$target" 2>/dev/null && return 0
  echo "" >> "$target"
  cat "$content_file" >> "$target"
}

# Compose shared knowledge dynamically based on which agents are present.
# Only activates when 2+ agents are composed (collaboration requires multiple roles).
# Generates collaboration.md from header + fragments of present agents.
# Copies any other _shared knowledge files as-is.
# Adds refs to ALL existing agent.md files.
# Usage: _copy_shared_knowledge <global_dir> <lang_dir> <project_path>
_copy_shared_knowledge() {
  local global_dir="$1" lang_dir="$2" project_path="$3"
  local agents_dir="${project_path}/.github/agents"
  local knowledge_dir="${project_path}/.github/knowledge"

  # Skip when fewer than 2 agents — collaboration requires multiple roles
  local agent_count
  agent_count="$(find "$agents_dir" -name "*.agent.md" 2>/dev/null | wc -l)"
  (( agent_count < 2 )) && return 0

  mkdir -p "$knowledge_dir"

  # ---- Compose collaboration.md dynamically ----
  # Always recompose — called multiple times as agents are added; last call wins
  # with the complete set of agents.
  local collab_out="${knowledge_dir}/collaboration.md"
  local header="${global_dir}/knowledge/shared/collaboration-header.md"
  if [[ -f "$header" ]]; then
    cat "$header" > "$collab_out"

    # Append fragments only for agents that exist in the project
    local agent_file agent_name fragment
    for agent_file in "$agents_dir"/*.agent.md; do
      [[ -f "$agent_file" ]] || continue
      agent_name="$(basename "$agent_file" .agent.md)"
      # Try global, then lang
      fragment="${global_dir}/knowledge/shared/collaboration-fragments/${agent_name}.md"
      if [[ -f "$fragment" ]]; then
        cat "$fragment" >> "$collab_out"
      fi
      fragment="${lang_dir}/knowledge/shared/collaboration-fragments/${agent_name}.md"
      if [[ -f "$fragment" ]]; then
        cat "$fragment" >> "$collab_out"
      fi
    done
  fi

  # ---- Copy any other shared knowledge files (skip fragments dir) ----
  local f
  for f in "${global_dir}/knowledge/shared"/*; do
    [[ -f "$f" ]] || continue
    local base; base="$(basename "$f")"
    [[ "$base" == "collaboration-header.md" ]] && continue
    local dst="${knowledge_dir}/${base}"
    [[ -f "$dst" ]] || cp "$f" "$dst"
  done
  for f in "${lang_dir}/knowledge/shared"/*; do
    [[ -f "$f" ]] || continue
    local base; base="$(basename "$f")"
    [[ "$base" == "collaboration-header.md" ]] && continue
    local dst="${knowledge_dir}/${base}"
    [[ -f "$dst" ]] || cp "$f" "$dst"
  done

  # ---- Add shared knowledge refs to ALL agent files ----
  local agent_file
  for agent_file in "$agents_dir"/*.agent.md; do
    [[ -f "$agent_file" ]] || continue
    local k
    for k in "${knowledge_dir}"/*.md; do
      [[ -f "$k" ]] || continue
      local ref=".github/knowledge/$(basename "$k")"
      if ! grep -Fq "$ref" "$agent_file" 2>/dev/null; then
        echo "- \`${ref}\`" >> "$agent_file"
      fi
    done
  done
}

# Copy files from src_dir to dst_dir without overwriting existing files.
_copy_files_noclobber() {
  local src_dir="$1" dst_dir="$2"
  [[ -d "$src_dir" ]] || return 0
  mkdir -p "$dst_dir"
  local f
  for f in "$src_dir"/*; do
    [[ -f "$f" ]] || continue
    local dst="${dst_dir}/$(basename "$f")"
    [[ -f "$dst" ]] || cp "$f" "$dst"
  done
}

# Copy prompt files matching a prefix to dst_dir (flat, no subdirs).
_copy_prompts_by_prefix() {
  local src_dir="$1" dst_dir="$2" prefix="$3"
  [[ -d "$src_dir" ]] || return 0
  mkdir -p "$dst_dir"
  local f
  for f in "$src_dir"/${prefix}*.prompt.md; do
    [[ -f "$f" ]] || continue
    local dst="${dst_dir}/$(basename "$f")"
    [[ -f "$dst" ]] || cp "$f" "$dst"
  done
}

# Copy skill directories (each skill is a dir with SKILL.md).
_copy_skills() {
  local src_dir="$1" dst_dir="$2" prefix="${3:-}"
  [[ -d "$src_dir" ]] || return 0
  local skill_d
  for skill_d in "$src_dir"/${prefix}*/; do
    [[ -d "$skill_d" ]] || continue
    local skill_name
    skill_name="$(basename "$skill_d")"
    local dst_skill="${dst_dir}/${skill_name}"
    mkdir -p "$dst_skill"
    local f
    for f in "$skill_d"*; do
      [[ -f "$f" ]] || continue
      local dst="${dst_skill}/$(basename "$f")"
      [[ -f "$dst" ]] || cp "$f" "$dst"
    done
  done
}

# Compose skills: append lang-specific content to existing global skill files.
_compose_skills() {
  local src_dir="$1" dst_dir="$2" prefix="${3:-}"
  [[ -d "$src_dir" ]] || return 0
  local skill_d
  for skill_d in "$src_dir"/${prefix}*/; do
    [[ -d "$skill_d" ]] || continue
    local skill_name
    skill_name="$(basename "$skill_d")"
    local dst_skill="${dst_dir}/${skill_name}"
    mkdir -p "$dst_skill"
    local f
    for f in "$skill_d"*; do
      [[ -f "$f" ]] || continue
      local base
      base="$(basename "$f")"
      local dst="${dst_skill}/${base}"
      if [[ -f "$dst" ]]; then
        echo "" >> "$dst"
        cat "$f" >> "$dst"
      else
        cp "$f" "$dst"
      fi
    done
  done
}

# Append isolation constraints to an agent.md based on which other agents exist.
# Skips if only 1 agent (no isolation needed).
# Recompose isolation constraints for ALL agents in the project.
# Called by every agent layer — "last call wins" with the complete set of agents.
# Removes old "## Isolation Rules" section and re-injects with current state.
# Skips entirely when fewer than 2 agents exist (no isolation needed).
# Usage: _recompose_isolation_constraints <project_path>
_recompose_isolation_constraints() {
  local project_path="$1"
  local agents_dir="${project_path}/.github/agents"

  # Collect all agent names
  local -a all_agents=()
  local f
  for f in "$agents_dir"/*.agent.md; do
    [[ -f "$f" ]] || continue
    all_agents+=("$(basename "$f" .agent.md)")
  done

  (( ${#all_agents[@]} < 2 )) && return 0

  local tpl_dir_agents; tpl_dir_agents="$(find_layer_templates_dir "shared" "agent-helpers")"

  local agent_name
  for agent_name in "${all_agents[@]}"; do
    local agent_md="${agents_dir}/${agent_name}.agent.md"
    [[ -f "$agent_md" ]] || continue

    # Remove old isolation section if present (everything from ## Isolation Rules to EOF or next ##)
    if grep -q "## Isolation Rules" "$agent_md" 2>/dev/null; then
      local iso_line
      iso_line="$(grep -n "## Isolation Rules" "$agent_md" | head -n1 | cut -d: -f1)"
      if [[ -n "$iso_line" ]]; then
        head -n "$((iso_line - 1))" "$agent_md" > "${agent_md}.tmp"
        mv "${agent_md}.tmp" "$agent_md"
      fi
    fi

    # Discover others (excluding self)
    local -a others=()
    local other
    for other in "${all_agents[@]}"; do
      [[ "$other" == "$agent_name" ]] && continue
      others+=("$other")
    done

    # Build prefix description (developer gets special treatment)
    local prefix
    if [[ "$agent_name" == "developer" ]]; then
      prefix='`developer-` or `dev-`'
    else
      prefix="\`${agent_name}-\`"
    fi

    local others_list others_prefixes
    others_list="$(printf "@%s, " "${others[@]}")"
    others_list="${others_list%, }"
    others_prefixes="$(printf "%s-, " "${others[@]}")"
    others_prefixes="${others_prefixes%, }"

    local isolation_tmp; isolation_tmp="$(make_temp)"
    render_template "$tpl_dir_agents/fragments/agent-isolation-rules.md" "$isolation_tmp" \
      "PREFIX=${prefix}" "AGENT_NAME=${agent_name}" \
      "OTHERS_PREFIXES=${others_prefixes}" "OTHERS_LIST=${others_list}"
    cat "$isolation_tmp" >> "$agent_md"
  done
}

# ===========================================================================
# _apply_content_agent_layer — Generic helper for content-only agent layers
# (po, qa-lead, tech-lead). Composes agent.md, knowledge, skills, prompts,
# copilot-instructions fragment.
#   $1 = project_path, $2 = name, $3 = lang
#   $4 = role (namespace in knowledge/skills/prompts)
#   $5 = agent filename base (e.g. "po", "qa-lead", "tech-lead")
#   $6 = fragment filename (e.g. "po.md", "qa-lead.md", "tech-lead.md")
#   $7 = section marker (e.g. "## Product", "## Quality", "## Architecture")
#   $8 = log label (e.g. "agent-po")
# ===========================================================================
_apply_content_agent_layer() {
  local project_path="$1"
  local name="${2:-}"
  local lang="${3:-python}"
  local role="$4"
  local agent_base="$5"
  local fragment_name="$6"
  local section_marker="$7"
  local log_label="$8"

  log "Applying layer: ${log_label} (AI-Powered Dev)"

  if ! _resolve_agents_base; then
    warn "templates/agents not found -- ${log_label} not applied"
    return 1
  fi

  local global_dir="${AGENTS_BASE}/global"
  local lang_dir="${AGENTS_BASE}/${lang}"

  mkdir -p "${project_path}/.github/agents"
  mkdir -p "${project_path}/.github/knowledge"
  mkdir -p "${project_path}/.github/skills"
  mkdir -p "${project_path}/.github/prompts"

  # ---- 1. Compose agent.md (global base + lang additions + knowledge refs) ----
  local agent_out="${project_path}/.github/agents/${agent_base}.agent.md"
  if [[ ! -f "$agent_out" ]]; then
    if [[ -f "${global_dir}/agents/${agent_base}.agent.md" ]]; then
      cat "${global_dir}/agents/${agent_base}.agent.md" > "$agent_out"
    fi
    if [[ -f "${lang_dir}/agents/${agent_base}.agent.md" ]]; then
      echo "" >> "$agent_out"
      cat "${lang_dir}/agents/${agent_base}.agent.md" >> "$agent_out"
    fi
    echo "" >> "$agent_out"
    echo "## Knowledge files" >> "$agent_out"
    echo "" >> "$agent_out"
    echo "Read and follow these for domain-specific guidance:" >> "$agent_out"
    echo "" >> "$agent_out"
  fi

  # ---- 2. Copy knowledge files (role namespace: global → lang) ----
  _copy_files_noclobber "${global_dir}/knowledge/${role}" "${project_path}/.github/knowledge/${role}"
  _copy_files_noclobber "${lang_dir}/knowledge/${role}" "${project_path}/.github/knowledge/${role}"

  if [[ -f "$agent_out" ]]; then
    local f
    for f in "${project_path}/.github/knowledge/${role}"/*.md; do
      [[ -f "$f" ]] || continue
      local ref=".github/knowledge/${role}/$(basename "$f")"
      if ! grep -Fq "$ref" "$agent_out" 2>/dev/null; then
        echo "- \`${ref}\`" >> "$agent_out"
      fi
    done
  fi

  # ---- 2b. Copy shared knowledge (accessible to all agents) ----
  _copy_shared_knowledge "${global_dir}" "${lang_dir}" "${project_path}"

  # ---- 3. Copy skills (flat, prefix-filtered: global → lang) ----
  _copy_skills "${global_dir}/skills" "${project_path}/.github/skills" "${role}-"
  _compose_skills "${lang_dir}/skills" "${project_path}/.github/skills" "${role}-"

  # ---- 4. Copy prompts (flat, prefix-filtered: global → lang) ----
  _copy_prompts_by_prefix "${global_dir}/prompts" "${project_path}/.github/prompts" "${role}-"
  _copy_prompts_by_prefix "${lang_dir}/prompts" "${project_path}/.github/prompts" "${role}-"

  # ---- 5. Compose copilot-instructions.md + AGENTS.md (fragment-based) ----
  local instructions_out="${project_path}/.github/copilot-instructions.md"
  local agents_md="${project_path}/AGENTS.md"

  local fragment="${lang_dir}/copilot-instructions-fragments/${fragment_name}"
  if [[ -f "$fragment" ]]; then
    _append_section "$instructions_out" "$section_marker" "$fragment"
    _append_section "$agents_md" "$section_marker" "$fragment"
  fi

  # ---- 6. Recompose isolation constraints for ALL agents ----
  _recompose_isolation_constraints "$project_path"

  echo "  Layer:    ${log_label} (AI-Powered Dev)"
}
