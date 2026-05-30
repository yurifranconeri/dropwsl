#!/usr/bin/env bash
# lib/layers/python/streamlit-auth.sh — Layer: Streamlit Authentication
# Self-contained users/ package providing form-based login for Streamlit apps.
# Ships require_login(), logout(), get_current_user() helpers and a
# `python -m <pkg>.users` CLI for user management (add, passwd, remove, list,
# gen-cookie-key, verify). Storage abstracted via CredentialStore Protocol;
# YamlStore is the default. NEVER modifies the user's main.py.
#
# Works in: any Streamlit app (showcase, chat, custom), src/ or flat layout,
# with or without uv, standalone or workspace.

[[ -n "${_STREAMLIT_AUTH_SH_LOADED:-}" ]] && return 0
_STREAMLIT_AUTH_SH_LOADED=1

_LAYER_PHASE="tooling"
_LAYER_CONFLICTS=""
_LAYER_REQUIRES="streamlit"

apply_layer_streamlit_auth() {
  local project_path="$1"
  local name="${2:-my-project}"
  local devcontainer_dir="${4:-${project_path}/.devcontainer}"

  log "Applying layer: streamlit-auth (self-contained users/ package)"

  local package_name; package_name="$(_to_package_name "$name")"
  _detect_python_layout "$project_path" "$package_name"
  local has_src="$_HAS_SRC"
  local pkg_base="$_PKG_BASE"

  local tpl_dir; tpl_dir="$(find_layer_templates_dir "python" "streamlit-auth")"

  # ---- requirements.txt ----
  inject_fragment "${tpl_dir}/fragments/requirements.txt" "${project_path}/requirements.txt"

  # ---- .env.example ----
  ensure_env_example "$project_path"
  # PKG_PREFIX deferred -- ensure_env_example is phase-agnostic; the fragment
  # placeholder is replaced below after pkg_prefix is computed.

  # ---- .gitignore ----
  if [[ -f "${project_path}/.gitignore" ]]; then
    inject_fragment "${tpl_dir}/fragments/gitignore.txt" "${project_path}/.gitignore"
  fi

  # ---- .dockerignore (defense-in-depth) ----
  _ensure_dockerignore "$project_path"
  inject_fragment "${tpl_dir}/fragments/dockerignore.txt" "${project_path}/.dockerignore"

  # ---- Idempotency: if users/ already exists, skip code generation ----
  if [[ -d "${pkg_base}/users" ]]; then
    log "Directory users/ already exists -- skipping code generation"
    echo "  Layer:    streamlit-auth [already applied]"
    return 0
  fi

  # ---- Render users/ package ----
  local pkg_prefix=""
  if [[ "$has_src" == true ]]; then
    pkg_prefix="${package_name}."
  fi

  # ---- .env.example: inject fragment now that pkg_prefix is known ----
  inject_fragment "${tpl_dir}/fragments/env.example" "${project_path}/.env.example" "PKG_PREFIX=${pkg_prefix}"

  mkdir -p "${pkg_base}/users"
  render_template "$tpl_dir/templates/users/__init__.py" "${pkg_base}/users/__init__.py" "PKG_PREFIX=${pkg_prefix}"
  render_template "$tpl_dir/templates/users/__main__.py" "${pkg_base}/users/__main__.py" "PKG_PREFIX=${pkg_prefix}"
  render_template "$tpl_dir/templates/users/gate.py"     "${pkg_base}/users/gate.py"     "PKG_PREFIX=${pkg_prefix}"
  render_template "$tpl_dir/templates/users/store.py"    "${pkg_base}/users/store.py"
  render_template "$tpl_dir/templates/users/cli.py"      "${pkg_base}/users/cli.py"      "PKG_PREFIX=${pkg_prefix}"

  # ---- Render users_data/ (config dir, never the package) ----
  mkdir -p "${project_path}/users_data"
  render_template "$tpl_dir/templates/users_data/credentials.example.yaml" "${project_path}/users_data/credentials.example.yaml" "PKG_PREFIX=${pkg_prefix}"
  render_template "$tpl_dir/templates/users_data/README.md"                "${project_path}/users_data/README.md" "PKG_PREFIX=${pkg_prefix}"

  # ---- Unit tests ----
  _inject_streamlit_auth_tests "$project_path" "$package_name" "$has_src" "$tpl_dir"

  # ---- README ----
  _inject_streamlit_auth_readme "$project_path" "$tpl_dir" "$pkg_prefix"

  echo "  Layer:    streamlit-auth (self-contained users/ package)"
}

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

# Ensures a .dockerignore file exists at project root (scaffold provides one,
# but we tolerate projects where it was removed).
_ensure_dockerignore() {
  local project_path="$1"
  local dockerignore="${project_path}/.dockerignore"
  if [[ ! -f "$dockerignore" ]]; then
    printf '# Docker build exclusions\n' > "$dockerignore"
  fi
}

# Copies unit tests for users module.
_inject_streamlit_auth_tests() {
  local project_path="$1"
  local package_name="$2"
  local has_src="$3"
  local tpl_dir="$4"

  local tests_dir="${project_path}/tests/unit"
  mkdir -p "$tests_dir"
  [[ -f "${tests_dir}/__init__.py" ]] || touch "${tests_dir}/__init__.py"

  local test_file="${tests_dir}/test_users.py"
  [[ -f "$test_file" ]] && return 0

  render_template "$tpl_dir/templates/tests/unit/test_users.py" "$test_file"

  if [[ "$has_src" == true ]]; then
    local sed_safe_prefix; sed_safe_prefix="$(_sed_escape "${package_name}.")"
    sed -i "s|from users\\.store import|from ${sed_safe_prefix}users.store import|" "$test_file"
    sed -i "s|from users\\.gate import|from ${sed_safe_prefix}users.gate import|" "$test_file"
  fi
}

# Injects Authentication section into README.md.
_inject_streamlit_auth_readme() {
  local project_path="$1"
  local tpl_dir="$2"
  local pkg_prefix="$3"

  local readme="${project_path}/README.md"
  [[ -f "$readme" ]] || return 0

  # Idempotency
  grep -Fq '## Authentication' "$readme" && return 0

  local section_tmp; section_tmp="$(make_temp)"
  render_template "${tpl_dir}/fragments/readme-streamlit-auth.md" "$section_tmp" "PKG_PREFIX=${pkg_prefix}"

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
