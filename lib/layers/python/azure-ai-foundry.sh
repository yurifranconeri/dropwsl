#!/usr/bin/env bash
# lib/layers/python/azure-ai-foundry.sh — Layer: Azure AI Foundry
# Self-contained foundry/ package with __main__.py CLI, FastAPI router (opt-in),
# and Streamlit panel (opt-in). NEVER modifies the user's main.py.
#
# Works in: FastAPI / Streamlit / console, src/ or flat layout, with or without uv,
# with or without compose, standalone or workspace.

[[ -n "${_AZURE_AI_FOUNDRY_SH_LOADED:-}" ]] && return 0
_AZURE_AI_FOUNDRY_SH_LOADED=1

_LAYER_PHASE="infra"
_LAYER_CONFLICTS=""
_LAYER_REQUIRES="azure-identity"

apply_layer_azure_ai_foundry() {
  local project_path="$1"
  local name="${2:-my-project}"
  local devcontainer_dir="${4:-${project_path}/.devcontainer}"

  log "Applying layer: azure-ai-foundry (self-contained foundry/ package)"

  local package_name; package_name="$(_to_package_name "$name")"
  _detect_python_layout "$project_path" "$package_name"
  local has_src="$_HAS_SRC"
  local pkg_base="$_PKG_BASE"

  local tpl_dir; tpl_dir="$(find_layer_templates_dir "python" "azure-ai-foundry")"

  # ---- requirements.txt ----
  inject_fragment "${tpl_dir}/fragments/requirements.txt" "${project_path}/requirements.txt"

  # ---- .env.example ----
  ensure_env_example "$project_path"
  inject_fragment "${tpl_dir}/fragments/env.example" "${project_path}/.env.example"

  # ---- conftest: requires_foundry fixture (auto-skip without endpoint) ----
  local conftest="${project_path}/tests/conftest.py"
  if [[ -f "$conftest" ]] && ! grep -Fq 'requires_foundry' "$conftest"; then
    inject_fragment_at "${tpl_dir}/fragments/conftest-fixture-foundry.py" "$conftest" "fixtures"
  fi

  # ---- Idempotency: if foundry/ already exists, skip code generation ----
  if [[ -d "${pkg_base}/foundry" ]]; then
    log "Directory foundry/ already exists -- skipping code generation"
    echo "  Layer:    azure-ai-foundry [already applied]"
    return 0
  fi

  # ---- Render package files ----
  local pkg_prefix=""
  if [[ "$has_src" == true ]]; then
    pkg_prefix="${package_name}."
  fi

  mkdir -p "${pkg_base}/foundry"
  render_template "$tpl_dir/templates/foundry/__init__.py"   "${pkg_base}/foundry/__init__.py"   "PKG_PREFIX=${pkg_prefix}"
  render_template "$tpl_dir/templates/foundry/client.py"     "${pkg_base}/foundry/client.py"
  render_template "$tpl_dir/templates/foundry/models.py"     "${pkg_base}/foundry/models.py"
  render_template "$tpl_dir/templates/foundry/connections.py" "${pkg_base}/foundry/connections.py"
  render_template "$tpl_dir/templates/foundry/__main__.py"   "${pkg_base}/foundry/__main__.py"   "PKG_PREFIX=${pkg_prefix}"
  render_template "$tpl_dir/templates/foundry/router.py"     "${pkg_base}/foundry/router.py"     "PKG_PREFIX=${pkg_prefix}"
  render_template "$tpl_dir/templates/foundry/ui.py"         "${pkg_base}/foundry/ui.py"         "PKG_PREFIX=${pkg_prefix}"

  # ---- Fix imports for src layout (only client.py imports from auth/) ----
  if [[ "$has_src" == true ]]; then
    local sed_safe_prefix; sed_safe_prefix="$(_sed_escape "${package_name}.")"
    sed -i "s|from auth\\.credential import|from ${sed_safe_prefix}auth.credential import|" "${pkg_base}/foundry/client.py"
  fi

  # ---- Unit tests ----
  _inject_foundry_tests "$project_path" "$package_name" "$has_src" "$tpl_dir"

  # ---- README.md ----
  _inject_foundry_readme "$project_path" "$tpl_dir" "$pkg_prefix"

  echo "  Layer:    azure-ai-foundry (self-contained foundry/ package)"
}

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

_inject_foundry_tests() {
  local project_path="$1"
  local package_name="$2"
  local has_src="$3"
  local tpl_dir="$4"

  local tests_dir="${project_path}/tests/unit"
  mkdir -p "$tests_dir"
  [[ -f "${tests_dir}/__init__.py" ]] || touch "${tests_dir}/__init__.py"

  local test_file="${tests_dir}/test_foundry.py"
  [[ -f "$test_file" ]] && return 0

  render_template "$tpl_dir/templates/tests/unit/test_foundry.py" "$test_file"

  if [[ "$has_src" == true ]]; then
    local sed_safe_prefix; sed_safe_prefix="$(_sed_escape "${package_name}.")"
    sed -i "s|import foundry\\.client as client_mod|import ${sed_safe_prefix}foundry.client as client_mod|" "$test_file"
    sed -i "s|import foundry\\.models as models_mod|import ${sed_safe_prefix}foundry.models as models_mod|" "$test_file"
    sed -i "s|import foundry\\.connections as connections_mod|import ${sed_safe_prefix}foundry.connections as connections_mod|" "$test_file"
  fi
}

_inject_foundry_readme() {
  local project_path="$1"
  local tpl_dir="$2"
  local pkg_prefix="$3"

  local readme="${project_path}/README.md"
  [[ -f "$readme" ]] || return 0

  grep -Fq 'Azure AI Foundry' "$readme" && return 0

  local section_tmp; section_tmp="$(make_temp)"
  render_template "${tpl_dir}/fragments/readme-foundry.md" "$section_tmp" "PKG_PREFIX=${pkg_prefix}"
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

  if ! grep -Fq '# Foundry (Azure' "$readme"; then
    if grep -Fq 'Auth (Azure' "$readme"; then
      sed -i '/Auth (Azure/a\├── foundry/                # Foundry (Azure AI Projects: client, models, connections, opt-in router/ui)' "$readme"
    elif grep -Fq 'Source code' "$readme"; then
      sed -i '/Source code/i\├── foundry/                # Foundry (Azure AI Projects: client, models, connections, opt-in router/ui)' "$readme"
    elif grep -Fq 'Entry point' "$readme"; then
      sed -i '/Entry point/i\├── foundry/                # Foundry (Azure AI Projects: client, models, connections, opt-in router/ui)' "$readme"
    fi
  fi
}
