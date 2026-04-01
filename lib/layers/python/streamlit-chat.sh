#!/usr/bin/env bash
# lib/layers/python/streamlit-chat.sh — Layer: Streamlit Chat UI
# Adds chat_ui/ package with HTTP client for the Chat API backend,
# and rewrites main.py with a ChatGPT-style streaming chat interface.

[[ -n "${_STREAMLIT_CHAT_SH_LOADED:-}" ]] && return 0
_STREAMLIT_CHAT_SH_LOADED=1

_LAYER_PHASE="infra-inject"
_LAYER_CONFLICTS=""
_LAYER_REQUIRES="streamlit"

apply_layer_streamlit_chat() {
  local project_path="$1"
  local name="${2:-my-project}"
  local devcontainer_dir="${4:-${project_path}/.devcontainer}"

  log "Applying layer: streamlit-chat (Chat UI)"

  local package_name; package_name="$(_to_package_name "$name")"
  _detect_python_layout "$project_path" "$package_name"
  local has_src="$_HAS_SRC"
  local pkg_base="$_PKG_BASE"

  local tpl_dir; tpl_dir="$(find_layer_templates_dir "python" "streamlit-chat")"

  # ---- Idempotency ----
  if [[ -d "${pkg_base}/chat_ui" ]]; then
    log "Directory chat_ui/ already exists -- skipping"
    echo "  Layer:    streamlit-chat [already applied]"
    return 0
  fi

  # ---- 1. Dependencies ----
  inject_fragment "${tpl_dir}/fragments/requirements.txt" "${project_path}/requirements.txt"

  # ---- 2. Create chat_ui/ package ----
  mkdir -p "${pkg_base}/chat_ui"
  render_template "$tpl_dir/templates/chat_ui/__init__.py" "${pkg_base}/chat_ui/__init__.py"
  render_template "$tpl_dir/templates/chat_ui/api.py" "${pkg_base}/chat_ui/api.py"

  # ---- 3. Rewrite main.py with Chat UI ----
  local main_py="${pkg_base}/main.py"
  local run_path="main.py"
  if [[ "$has_src" == true ]]; then
    run_path="src/${package_name}/main.py"
  fi

  if [[ -f "$main_py" ]]; then
    render_template "$tpl_dir/templates/main.py" "$main_py" "PROJECT_NAME=${name}"
  fi

  # NOTE: No src prefix fixup needed for main.py or __init__.py.
  # Streamlit adds the script's directory to sys.path, so bare
  # "from chat_ui.api import" works at runtime and in AppTest.
  # __init__.py uses relative imports ("from .api import") which
  # are always valid within the package.

  # ---- 5. .env.example ----
  ensure_env_example "$project_path"
  inject_fragment "${tpl_dir}/fragments/env.example" "${project_path}/.env.example"

  # ---- 6. Tests ----
  local test_file="${project_path}/tests/test_main.py"
  if [[ -f "$test_file" ]] && ! grep -q 'chat_input' "$test_file" 2>/dev/null; then
    render_template "$tpl_dir/templates/tests/test_main.py" "$test_file" "TEST_PATH=${run_path}"
  fi

  # ---- 7. README ----
  _inject_streamlit_chat_readme "$project_path" "$tpl_dir"

  echo "  Layer:    streamlit-chat (Chat UI)"
}

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

_inject_streamlit_chat_readme() {
  local project_path="$1"
  local tpl_dir="$2"

  local readme="${project_path}/README.md"
  [[ -f "$readme" ]] || return 0

  # Idempotency
  grep -Fq 'Chat UI' "$readme" && return 0

  local section_tmp; section_tmp="$(make_temp)"
  cp "$tpl_dir/fragments/readme-streamlit-chat.md" "$section_tmp"
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
    cp "$tmp" "$readme"
  else
    echo "" >> "$readme"
    cat "$section_tmp" >> "$readme"
  fi
}
