#!/usr/bin/env bash
# lib/layers/python/azure-ai-chat.sh — Layer: Azure AI Chat
# Self-contained chat/ package with __main__.py CLI, FastAPI router (opt-in),
# and Streamlit panel (opt-in). NEVER modifies the user's main.py.
#
# Works in: FastAPI / Streamlit / console, src/ or flat layout, with or without uv,
# with or without compose, standalone or workspace.

[[ -n "${_AZURE_AI_CHAT_SH_LOADED:-}" ]] && return 0
_AZURE_AI_CHAT_SH_LOADED=1

_LAYER_PHASE="infra"
_LAYER_CONFLICTS=""
_LAYER_REQUIRES="azure-ai-foundry"

apply_layer_azure_ai_chat() {
  local project_path="$1"
  local name="${2:-my-project}"
  local devcontainer_dir="${4:-${project_path}/.devcontainer}"

  log "Applying layer: azure-ai-chat (self-contained chat/ package)"

  local package_name; package_name="$(_to_package_name "$name")"
  _detect_python_layout "$project_path" "$package_name"
  local has_src="$_HAS_SRC"
  local pkg_base="$_PKG_BASE"

  local tpl_dir; tpl_dir="$(find_layer_templates_dir "python" "azure-ai-chat")"

  # ---- .env.example ----
  ensure_env_example "$project_path"
  inject_fragment "${tpl_dir}/fragments/env.example" "${project_path}/.env.example"

  # ---- Idempotency: if chat/ already exists, skip code generation ----
  if [[ -d "${pkg_base}/chat" ]]; then
    log "Directory chat/ already exists -- skipping code generation"
    echo "  Layer:    azure-ai-chat [already applied]"
    return 0
  fi

  # ---- Render package files ----
  local pkg_prefix=""
  if [[ "$has_src" == true ]]; then
    pkg_prefix="${package_name}."
  fi

  mkdir -p "${pkg_base}/chat"
  render_template "$tpl_dir/templates/chat/__init__.py"    "${pkg_base}/chat/__init__.py"    "PKG_PREFIX=${pkg_prefix}"
  render_template "$tpl_dir/templates/chat/__main__.py"    "${pkg_base}/chat/__main__.py"    "PKG_PREFIX=${pkg_prefix}"
  render_template "$tpl_dir/templates/chat/_common.py"     "${pkg_base}/chat/_common.py"
  render_template "$tpl_dir/templates/chat/responses.py"   "${pkg_base}/chat/responses.py"
  render_template "$tpl_dir/templates/chat/completions.py" "${pkg_base}/chat/completions.py"
  render_template "$tpl_dir/templates/chat/models.py"      "${pkg_base}/chat/models.py"
  render_template "$tpl_dir/templates/chat/router.py"      "${pkg_base}/chat/router.py"
  render_template "$tpl_dir/templates/chat/ui.py"          "${pkg_base}/chat/ui.py"

  # ---- Fix imports for src layout (chat → foundry runtime dependency) ----
  if [[ "$has_src" == true ]]; then
    local sed_safe_prefix; sed_safe_prefix="$(_sed_escape "${package_name}.")"
    sed -i "s|from foundry\\.client import|from ${sed_safe_prefix}foundry.client import|" "${pkg_base}/chat/responses.py"
    sed -i "s|from foundry\\.client import|from ${sed_safe_prefix}foundry.client import|" "${pkg_base}/chat/completions.py"
  fi

  # ---- Unit tests ----
  _inject_chat_tests "$project_path" "$package_name" "$has_src" "$tpl_dir"

  # ---- README.md ----
  _inject_chat_readme "$project_path" "$tpl_dir" "$pkg_prefix"

  echo "  Layer:    azure-ai-chat (self-contained chat/ package)"
}

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

_inject_chat_tests() {
  local project_path="$1"
  local package_name="$2"
  local has_src="$3"
  local tpl_dir="$4"

  local tests_dir="${project_path}/tests/unit"
  mkdir -p "$tests_dir"
  [[ -f "${tests_dir}/__init__.py" ]] || touch "${tests_dir}/__init__.py"

  local test_file="${tests_dir}/test_chat.py"
  [[ -f "$test_file" ]] && return 0

  render_template "$tpl_dir/templates/tests/unit/test_chat.py" "$test_file"

  if [[ "$has_src" == true ]]; then
    local sed_safe_prefix; sed_safe_prefix="$(_sed_escape "${package_name}.")"
    sed -i "s|import chat\\.responses as responses_mod|import ${sed_safe_prefix}chat.responses as responses_mod|" "$test_file"
    sed -i "s|import chat\\.completions as completions_mod|import ${sed_safe_prefix}chat.completions as completions_mod|" "$test_file"
    sed -i "s|import chat\\._common as common_mod|import ${sed_safe_prefix}chat._common as common_mod|" "$test_file"
    sed -i "s|from chat\\.models import|from ${sed_safe_prefix}chat.models import|" "$test_file"
  fi
}

_inject_chat_readme() {
  local project_path="$1"
  local tpl_dir="$2"
  local pkg_prefix="$3"

  local readme="${project_path}/README.md"
  [[ -f "$readme" ]] || return 0

  grep -Fq 'Chat (Responses' "$readme" && return 0

  local section_tmp; section_tmp="$(make_temp)"
  render_template "${tpl_dir}/fragments/readme-chat.md" "$section_tmp" "PKG_PREFIX=${pkg_prefix}"
  sed -i 's/\r$//' "$section_tmp"

  if grep -q '^## Docker' "$readme"; then
    local docker_line
    docker_line="$(grep -n '^## Docker' "$readme" | head -n1 | cut -d: -f1)"
    local tmp; tmp="$(make_temp)"
    head -n "$((docker_line - 1))" "$readme" > "$tmp"
    echo "" >> "$tmp"
    cat "$section_tmp" >> "$tmp"
    echo "" >> "$tmp"
    tail -n "+${docker_line}" "$readme" >> "$tmp"
    mv "$tmp" "$readme"
  else
    echo "" >> "$readme"
    cat "$section_tmp" >> "$readme"
  fi

  if ! grep -Fq '├── chat/' "$readme"; then
    if grep -Fq 'foundry/' "$readme"; then
      sed -i '/├── foundry\//a\├── chat/                   # Chat (Responses + Completions, opt-in router/ui)' "$readme"
    elif grep -Fq 'Source code' "$readme"; then
      sed -i '/Source code/i\├── chat/                   # Chat (Responses + Completions, opt-in router/ui)' "$readme"
    elif grep -Fq 'Entry point' "$readme"; then
      sed -i '/Entry point/i\├── chat/                   # Chat (Responses + Completions, opt-in router/ui)' "$readme"
    fi
  fi
}
