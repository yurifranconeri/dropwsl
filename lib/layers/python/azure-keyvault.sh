#!/usr/bin/env bash
# lib/layers/python/azure-keyvault.sh — Layer: Azure Key Vault
# Self-contained keyvault/ package with __main__.py CLI, FastAPI router (opt-in),
# and Streamlit panel (opt-in). NEVER modifies the user's main.py.
#
# Works in: FastAPI / Streamlit / console, src/ or flat layout, with or without uv,
# with or without compose, standalone or workspace.

[[ -n "${_AZURE_KEYVAULT_SH_LOADED:-}" ]] && return 0
_AZURE_KEYVAULT_SH_LOADED=1

_LAYER_PHASE="infra"
_LAYER_CONFLICTS=""
_LAYER_REQUIRES="azure-identity"

apply_layer_azure_keyvault() {
  local project_path="$1"
  local name="${2:-my-project}"
  local devcontainer_dir="${4:-${project_path}/.devcontainer}"

  log "Applying layer: azure-keyvault (self-contained keyvault/ package)"

  local package_name; package_name="$(_to_package_name "$name")"
  _detect_python_layout "$project_path" "$package_name"
  local has_src="$_HAS_SRC"
  local pkg_base="$_PKG_BASE"

  local tpl_dir; tpl_dir="$(find_layer_templates_dir "python" "azure-keyvault")"

  # ---- requirements.txt ----
  inject_fragment "${tpl_dir}/fragments/requirements.txt" "${project_path}/requirements.txt"

  # ---- .env.example ----
  ensure_env_example "$project_path"
  inject_fragment "${tpl_dir}/fragments/env.example" "${project_path}/.env.example"

  # ---- Idempotency: if keyvault/ already exists, skip code generation ----
  if [[ -d "${pkg_base}/keyvault" ]]; then
    log "Directory keyvault/ already exists -- skipping code generation"
    echo "  Layer:    azure-keyvault [already applied]"
    return 0
  fi

  # ---- Render package files ----
  local pkg_prefix=""
  if [[ "$has_src" == true ]]; then
    pkg_prefix="${package_name}."
  fi

  mkdir -p "${pkg_base}/keyvault"
  render_template "$tpl_dir/templates/keyvault/__init__.py"  "${pkg_base}/keyvault/__init__.py"  "PKG_PREFIX=${pkg_prefix}"
  render_template "$tpl_dir/templates/keyvault/client.py"    "${pkg_base}/keyvault/client.py"
  render_template "$tpl_dir/templates/keyvault/secrets.py"   "${pkg_base}/keyvault/secrets.py"
  render_template "$tpl_dir/templates/keyvault/__main__.py"  "${pkg_base}/keyvault/__main__.py"  "PKG_PREFIX=${pkg_prefix}"
  render_template "$tpl_dir/templates/keyvault/router.py"    "${pkg_base}/keyvault/router.py"    "PKG_PREFIX=${pkg_prefix}"
  render_template "$tpl_dir/templates/keyvault/ui.py"        "${pkg_base}/keyvault/ui.py"        "PKG_PREFIX=${pkg_prefix}"

  # ---- Fix imports for src layout (only client.py imports from auth/) ----
  if [[ "$has_src" == true ]]; then
    local sed_safe_prefix; sed_safe_prefix="$(_sed_escape "${package_name}.")"
    sed -i "s|from auth\\.credential import|from ${sed_safe_prefix}auth.credential import|" "${pkg_base}/keyvault/client.py"
  fi

  # ---- Unit tests ----
  _inject_keyvault_tests "$project_path" "$package_name" "$has_src" "$tpl_dir"

  # ---- README ----
  _inject_keyvault_readme "$project_path" "$tpl_dir" "$pkg_prefix"

  echo "  Layer:    azure-keyvault (self-contained keyvault/ package)"
}

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

# Copies unit tests for keyvault module.
_inject_keyvault_tests() {
  local project_path="$1"
  local package_name="$2"
  local has_src="$3"
  local tpl_dir="$4"

  local tests_dir="${project_path}/tests/unit"
  mkdir -p "$tests_dir"
  [[ -f "${tests_dir}/__init__.py" ]] || touch "${tests_dir}/__init__.py"

  local test_file="${tests_dir}/test_keyvault.py"
  [[ -f "$test_file" ]] && return 0

  render_template "$tpl_dir/templates/tests/unit/test_keyvault.py" "$test_file"

  if [[ "$has_src" == true ]]; then
    local sed_safe_prefix; sed_safe_prefix="$(_sed_escape "${package_name}.")"
    sed -i "s|import keyvault\\.client as client_mod|import ${sed_safe_prefix}keyvault.client as client_mod|" "$test_file"
    sed -i "s|import keyvault\\.secrets as secrets_mod|import ${sed_safe_prefix}keyvault.secrets as secrets_mod|" "$test_file"
    sed -i "s|logger=\"keyvault\\.secrets\"|logger=\"${sed_safe_prefix}keyvault.secrets\"|" "$test_file"
  fi
}

# Injects Azure Key Vault section into README.md.
_inject_keyvault_readme() {
  local project_path="$1"
  local tpl_dir="$2"
  local pkg_prefix="$3"

  local readme="${project_path}/README.md"
  [[ -f "$readme" ]] || return 0

  # Idempotency
  grep -Fq 'Azure Key Vault' "$readme" && return 0

  local section_tmp; section_tmp="$(make_temp)"
  render_template "${tpl_dir}/fragments/readme-keyvault.md" "$section_tmp" "PKG_PREFIX=${pkg_prefix}"
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

  # Update structure tree — add keyvault/
  if ! grep -Fq '# Key Vault' "$readme"; then
    if grep -Fq 'Foundry (Azure' "$readme"; then
      sed -i '/Foundry (Azure/a\├── keyvault/               # Key Vault (secrets metadata + opt-in router/ui)' "$readme"
    elif grep -Fq 'Auth (Azure' "$readme"; then
      sed -i '/Auth (Azure/a\├── keyvault/               # Key Vault (secrets metadata + opt-in router/ui)' "$readme"
    elif grep -Fq 'Source code' "$readme"; then
      sed -i '/Source code/i\├── keyvault/               # Key Vault (secrets metadata + opt-in router/ui)' "$readme"
    elif grep -Fq 'Entry point' "$readme"; then
      sed -i '/Entry point/i\├── keyvault/               # Key Vault (secrets metadata + opt-in router/ui)' "$readme"
    fi
  fi
}
