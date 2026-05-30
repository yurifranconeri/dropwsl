#!/usr/bin/env bash
# lib/layers/python/pydantic-settings.sh — Layer: Typed config via pydantic-settings
# Self-contained config/ package with Settings(BaseSettings), get_settings()
# lru_cached, and `python -m <pkg>.config` CLI inspector (show, validate,
# dump-env, schema). Loads from environment variables and .env, fails fast
# on missing/invalid fields, masks SecretStr in logs and dumps. NEVER modifies
# the user's main.py, compose.yaml, or devcontainer.json.
#
# Works in: FastAPI, Streamlit, console scripts, src/ or flat layout,
# with or without uv, standalone or workspace.

[[ -n "${_PYDANTIC_SETTINGS_SH_LOADED:-}" ]] && return 0
_PYDANTIC_SETTINGS_SH_LOADED=1

_LAYER_PHASE="tooling"
_LAYER_CONFLICTS=""
_LAYER_REQUIRES=""

apply_layer_pydantic_settings() {
  local project_path="$1"
  local name="${2:-my-project}"
  local devcontainer_dir="${4:-${project_path}/.devcontainer}"

  log "Applying layer: pydantic-settings (self-contained config/ package)"

  local package_name; package_name="$(_to_package_name "$name")"
  _detect_python_layout "$project_path" "$package_name"
  local has_src="$_HAS_SRC"
  local pkg_base="$_PKG_BASE"

  local tpl_dir; tpl_dir="$(find_layer_templates_dir "python" "pydantic-settings")"

  # ---- requirements.txt ----
  # Note: pydantic core is already pinned by the base template. We only add
  # pydantic-settings here. No conditional logic for uv -- the uv layer keeps
  # using requirements.txt (it only swaps `pip` for `uv pip install -r ...`).
  inject_fragment "${tpl_dir}/fragments/requirements.txt" "${project_path}/requirements.txt"

  # ---- .env.example ----
  ensure_env_example "$project_path"
  inject_fragment "${tpl_dir}/fragments/env.example" "${project_path}/.env.example" \
    "PROJECT_NAME=${name}"

  # ---- Idempotency: if config/ already exists, skip code generation ----
  if [[ -d "${pkg_base}/config" ]]; then
    log "Directory config/ already exists -- skipping code generation"
    echo "  Layer:    pydantic-settings [already applied]"
    return 0
  fi

  # ---- Determine import prefix for src layout ----
  local pkg_prefix=""
  if [[ "$has_src" == true ]]; then
    pkg_prefix="${package_name}."
  fi

  # ---- Render config/ package ----
  mkdir -p "${pkg_base}/config"
  render_template "$tpl_dir/templates/config/__init__.py" \
    "${pkg_base}/config/__init__.py" "PKG_PREFIX=${pkg_prefix}"
  render_template "$tpl_dir/templates/config/__main__.py" \
    "${pkg_base}/config/__main__.py" "PKG_PREFIX=${pkg_prefix}"
  render_template "$tpl_dir/templates/config/settings.py" \
    "${pkg_base}/config/settings.py" \
    "PKG_PREFIX=${pkg_prefix}" "PROJECT_NAME=${name}"
  render_template "$tpl_dir/templates/config/cli.py" \
    "${pkg_base}/config/cli.py" "PKG_PREFIX=${pkg_prefix}"

  # ---- Unit tests ----
  _inject_pydantic_settings_tests "$project_path" "$package_name" "$has_src" "$tpl_dir"

  # ---- README ----
  _inject_pydantic_settings_readme "$project_path" "$tpl_dir" "$pkg_prefix"

  echo "  Layer:    pydantic-settings (self-contained config/ package)"
}

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

# Copies the pytest test template, rewriting imports for src layout.
_inject_pydantic_settings_tests() {
  local project_path="$1"
  local package_name="$2"
  local has_src="$3"
  local tpl_dir="$4"

  local tests_dir="${project_path}/tests/unit"
  mkdir -p "$tests_dir"
  [[ -f "${tests_dir}/__init__.py" ]] || touch "${tests_dir}/__init__.py"

  local test_file="${tests_dir}/test_config.py"
  [[ -f "$test_file" ]] && return 0

  render_template "$tpl_dir/templates/tests/unit/test_config.py" "$test_file"

  if [[ "$has_src" == true ]]; then
    local sed_safe_prefix; sed_safe_prefix="$(_sed_escape "${package_name}.")"
    sed -i "s|from config\\.settings import|from ${sed_safe_prefix}config.settings import|" "$test_file"
    sed -i "s|from config import|from ${sed_safe_prefix}config import|" "$test_file"
  fi
}

# Injects ## Configuration section into README.md, before ## Docker if present.
_inject_pydantic_settings_readme() {
  local project_path="$1"
  local tpl_dir="$2"
  local pkg_prefix="$3"

  local readme="${project_path}/README.md"
  [[ -f "$readme" ]] || return 0

  # Idempotency
  grep -Fq '## Configuration' "$readme" && return 0

  local section_tmp; section_tmp="$(make_temp)"
  render_template "${tpl_dir}/fragments/readme-pydantic-settings.md" \
    "$section_tmp" "PKG_PREFIX=${pkg_prefix}"

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
