#!/usr/bin/env bash
# lib/layers/python/azure-ai-chat.sh — Layer: Azure AI Chat
# Adds chat/ package with Responses API + Chat Completions API,
# Pydantic models, and /api/chat + /api/chat/stream endpoints.

[[ -n "${_AZURE_AI_CHAT_SH_LOADED:-}" ]] && return 0
_AZURE_AI_CHAT_SH_LOADED=1

_LAYER_PHASE="infra-inject"
_LAYER_CONFLICTS=""
_LAYER_REQUIRES="azure-ai-foundry"

apply_layer_azure_ai_chat() {
  local project_path="$1"
  local name="${2:-my-project}"
  local devcontainer_dir="${4:-${project_path}/.devcontainer}"

  log "Applying layer: azure-ai-chat (Responses + Completions API)"

  local package_name; package_name="$(_to_package_name "$name")"
  _detect_python_layout "$project_path" "$package_name"
  local has_src="$_HAS_SRC"
  local pkg_base="$_PKG_BASE"
  local has_async_api="$_HAS_API_FRAMEWORK"

  local tpl_dir; tpl_dir="$(find_layer_templates_dir "python" "azure-ai-chat")"

  # ---- Idempotency: if chat/ already exists, skip generation ----
  if [[ -d "${pkg_base}/chat" ]]; then
    log "Directory chat/ already exists -- skipping code generation"
    echo "  Layer:    azure-ai-chat [already applied]"
    return 0
  fi

  # ---- Create chat/ package ----
  mkdir -p "${pkg_base}/chat"
  render_template "$tpl_dir/templates/chat/__init__.py" "${pkg_base}/chat/__init__.py"
  render_template "$tpl_dir/templates/chat/_common.py" "${pkg_base}/chat/_common.py"
  render_template "$tpl_dir/templates/chat/responses.py" "${pkg_base}/chat/responses.py"
  render_template "$tpl_dir/templates/chat/completions.py" "${pkg_base}/chat/completions.py"
  render_template "$tpl_dir/templates/chat/models.py" "${pkg_base}/chat/models.py"

  # ---- Fix import paths for src layout ----
  if [[ "$has_src" == true ]]; then
    local sed_safe_prefix; sed_safe_prefix="$(_sed_escape "${package_name}.")"
    # responses.py + completions.py: foundry import
    sed -i "s|from foundry\.client import|from ${sed_safe_prefix}foundry.client import|" "${pkg_base}/chat/responses.py"
    sed -i "s|from foundry\.client import|from ${sed_safe_prefix}foundry.client import|" "${pkg_base}/chat/completions.py"
    # responses.py + completions.py: relative _common import
    sed -i "s|from \._common import|from ${sed_safe_prefix}chat._common import|" "${pkg_base}/chat/responses.py"
    sed -i "s|from \._common import|from ${sed_safe_prefix}chat._common import|" "${pkg_base}/chat/completions.py"
    # __init__.py: relative imports → absolute
    sed -i "s|from \._common import|from ${sed_safe_prefix}chat._common import|" "${pkg_base}/chat/__init__.py"
    sed -i "s|from \.completions import|from ${sed_safe_prefix}chat.completions import|" "${pkg_base}/chat/__init__.py"
    sed -i "s|from \.models import|from ${sed_safe_prefix}chat.models import|" "${pkg_base}/chat/__init__.py"
    sed -i "s|from \.responses import|from ${sed_safe_prefix}chat.responses import|" "${pkg_base}/chat/__init__.py"
  fi

  # ---- .env.example ----
  ensure_env_example "$project_path"
  inject_fragment "${tpl_dir}/fragments/env.example" "${project_path}/.env.example"

  # ---- main.py: standalone vs API ----
  if $has_async_api; then
    _inject_chat_api "$project_path" "$package_name" "$has_src" "$tpl_dir"
  else
    _inject_chat_standalone "$project_path" "$package_name" "$has_src" "$tpl_dir"
  fi

  # ---- Unit tests ----
  _inject_chat_tests "$project_path" "$package_name" "$has_src" "$tpl_dir"

  # ---- README.md ----
  _inject_chat_readme "$project_path" "$tpl_dir"

  echo "  Layer:    azure-ai-chat (Responses + Completions API)"
}

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

# Injects chat imports and routes into FastAPI main.py.
_inject_chat_api() {
  local project_path="$1"
  local package_name="$2"
  local has_src="$3"
  local tpl_dir="$4"

  local main_py=""
  if [[ "$has_src" == true ]]; then
    main_py="${project_path}/src/${package_name}/main.py"
  else
    main_py="${project_path}/main.py"
  fi
  [[ -f "$main_py" ]] || return 0

  # Idempotency: already has chat imports
  if grep -Fq 'send_message' "$main_py"; then
    return 0
  fi

  local import_prefix=""
  if [[ "$has_src" == true ]]; then
    import_prefix="${package_name}."
  fi

  # ---- Import chat modules ----
  local last_import_line
  last_import_line="$(grep -n '^from\|^import' "$main_py" | tail -n1 | cut -d: -f1)"
  if [[ -n "$last_import_line" ]]; then
    local chat_import_tmp; chat_import_tmp="$(make_temp)"
    render_template "$tpl_dir/fragments/main-import-chat.py" "$chat_import_tmp" "IMPORT_PREFIX=${import_prefix}"
    sed -i "${last_import_line}r ${chat_import_tmp}" "$main_py"
  fi

  # ---- /api/chat routes ----
  if ! grep -Fq '/api/chat' "$main_py"; then
    local routes_tmp; routes_tmp="$(make_temp)"
    cp "$tpl_dir/fragments/main-routes-chat.py" "$routes_tmp"
    sed -i 's/\r$//' "$routes_tmp"

    # Insert before `if __name__` block
    local main_block_line
    main_block_line="$(grep -Fn 'if __name__' "$main_py" | head -n1 | cut -d: -f1)"
    if [[ -n "$main_block_line" ]]; then
      sed -i "$((main_block_line - 1))r ${routes_tmp}" "$main_py"
    else
      cat "$routes_tmp" >> "$main_py"
    fi
  fi
}

# Replaces standalone main.py with chat-capable version.
_inject_chat_standalone() {
  local project_path="$1"
  local package_name="$2"
  local has_src="$3"
  local tpl_dir="$4"

  local main_py=""
  if [[ "$has_src" == true ]]; then
    main_py="${project_path}/src/${package_name}/main.py"
  else
    main_py="${project_path}/main.py"
  fi
  [[ -f "$main_py" ]] || return 0

  # Idempotency: already has chat import
  if grep -Fq 'send_message' "$main_py"; then
    return 0
  fi

  render_template "$tpl_dir/templates/main.py" "$main_py"

  # Fix import paths for src layout
  if [[ "$has_src" == true ]]; then
    local sed_safe_prefix; sed_safe_prefix="$(_sed_escape "${package_name}.")"
    sed -i "s|from foundry\\.client import|from ${sed_safe_prefix}foundry.client import|" "$main_py"
    sed -i "s|from chat import|from ${sed_safe_prefix}chat import|" "$main_py"
    sed -i "s|from chat\.responses import|from ${sed_safe_prefix}chat.responses import|" "$main_py"
  fi
}

# Copies unit tests for chat module.
_inject_chat_tests() {
  local project_path="$1"
  local package_name="$2"
  local has_src="$3"
  local tpl_dir="$4"

  local tests_dir="${project_path}/tests/unit"
  mkdir -p "$tests_dir"
  [[ -f "${project_path}/tests/unit/__init__.py" ]] || touch "${project_path}/tests/unit/__init__.py"

  local test_file="${tests_dir}/test_chat.py"
  [[ -f "$test_file" ]] && return 0

  render_template "$tpl_dir/templates/tests/unit/test_chat.py" "$test_file"

  # Fix import path for src layout
  if [[ "$has_src" == true ]]; then
    local sed_safe_prefix; sed_safe_prefix="$(_sed_escape "${package_name}.")"
    sed -i "s|import chat\.responses as responses_mod|import ${sed_safe_prefix}chat.responses as responses_mod|" "$test_file"
    sed -i "s|import chat\.completions as completions_mod|import ${sed_safe_prefix}chat.completions as completions_mod|" "$test_file"
    sed -i "s|import chat\._common as common_mod|import ${sed_safe_prefix}chat._common as common_mod|" "$test_file"
    sed -i "s|from chat\.models import|from ${sed_safe_prefix}chat.models import|" "$test_file"
  fi
}

# Injects Azure AI Chat section into README.md.
_inject_chat_readme() {
  local project_path="$1"
  local tpl_dir="$2"

  local readme="${project_path}/README.md"
  [[ -f "$readme" ]] || return 0

  # Idempotency
  grep -Fq 'Chat (Responses' "$readme" && return 0

  local section_tmp; section_tmp="$(make_temp)"
  cp "$tpl_dir/fragments/readme-chat.md" "$section_tmp"
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

  # Update structure tree — add chat/
  if ! grep -Fq '# Chat (Responses' "$readme"; then
    if grep -Fq 'Foundry (Azure' "$readme"; then
      sed -i '/Foundry (Azure/a\├── chat/                   # Chat (Responses + Completions API)' "$readme"
    elif grep -Fq 'Source code' "$readme"; then
      sed -i '/Source code/i\├── chat/                   # Chat (Responses + Completions API)' "$readme"
    elif grep -Fq 'Entry point' "$readme"; then
      sed -i '/Entry point/i\├── chat/                   # Chat (Responses + Completions API)' "$readme"
    fi
  fi
}
