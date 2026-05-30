#!/usr/bin/env bash
# lib/layers/python/azure-identity.sh — Layer: Azure Identity
# Self-contained auth/ package with __main__.py CLI, FastAPI router (opt-in),
# and Streamlit panel (opt-in). NEVER modifies the user's main.py.
#
# Works in: FastAPI / Streamlit / console, src/ or flat layout, with or without uv,
# with or without compose, standalone or workspace.
#
# Infra concerns (NOT main.py mutation, kept here):
#   - azure-cli devcontainer feature (so `az login` works inside the container)
#   - post-create.sh `az account show` check (early signal)
#   - conftest.py requires_azure fixture (auto-skip tests without credentials)

[[ -n "${_AZURE_IDENTITY_SH_LOADED:-}" ]] && return 0
_AZURE_IDENTITY_SH_LOADED=1

_LAYER_PHASE="infra"
_LAYER_CONFLICTS=""
_LAYER_REQUIRES=""

apply_layer_azure_identity() {
  local project_path="$1"
  local name="${2:-my-project}"
  local devcontainer_dir="${4:-${project_path}/.devcontainer}"

  log "Applying layer: azure-identity (self-contained auth/ package)"

  local package_name; package_name="$(_to_package_name "$name")"
  _detect_python_layout "$project_path" "$package_name"
  local has_src="$_HAS_SRC"
  local pkg_base="$_PKG_BASE"

  local tpl_dir; tpl_dir="$(find_layer_templates_dir "python" "azure-identity")"

  # ---- requirements.txt ----
  inject_fragment "${tpl_dir}/fragments/requirements.txt" "${project_path}/requirements.txt"

  # ---- .env.example ----
  ensure_env_example "$project_path"
  inject_fragment "${tpl_dir}/fragments/env.example" "${project_path}/.env.example"

  # ---- devcontainer: add azure-cli feature ----
  _inject_azure_cli_feature "${devcontainer_dir}/devcontainer.json" "$tpl_dir"

  # ---- post-create.sh: az login check before "Environment ready" ----
  _inject_az_login_check "${devcontainer_dir}/post-create.sh" "$tpl_dir"

  # ---- conftest: requires_azure fixture (auto-skip without credentials) ----
  local conftest="${project_path}/tests/conftest.py"
  if [[ -f "$conftest" ]] && ! grep -Fq 'requires_azure' "$conftest"; then
    inject_fragment_at "${tpl_dir}/fragments/conftest-fixture-azure.py" "$conftest" "fixtures"
  fi

  # ---- Idempotency: if auth/ already exists, skip code generation ----
  if [[ -d "${pkg_base}/auth" ]]; then
    log "Directory auth/ already exists -- skipping code generation"
    echo "  Layer:    azure-identity [already applied]"
    return 0
  fi

  # ---- Render package files ----
  local pkg_prefix=""
  if [[ "$has_src" == true ]]; then
    pkg_prefix="${package_name}."
  fi

  mkdir -p "${pkg_base}/auth"
  render_template "$tpl_dir/templates/auth/__init__.py" "${pkg_base}/auth/__init__.py" "PKG_PREFIX=${pkg_prefix}"
  render_template "$tpl_dir/templates/auth/credential.py" "${pkg_base}/auth/credential.py"
  render_template "$tpl_dir/templates/auth/__main__.py" "${pkg_base}/auth/__main__.py" "PKG_PREFIX=${pkg_prefix}"
  render_template "$tpl_dir/templates/auth/router.py"   "${pkg_base}/auth/router.py"   "PKG_PREFIX=${pkg_prefix}"
  render_template "$tpl_dir/templates/auth/ui.py"       "${pkg_base}/auth/ui.py"       "PKG_PREFIX=${pkg_prefix}"

  # ---- Unit tests ----
  _inject_identity_tests "$project_path" "$package_name" "$has_src" "$tpl_dir"

  # ---- README.md ----
  _inject_identity_readme "$project_path" "$tpl_dir" "$pkg_prefix"

  echo "  Layer:    azure-identity (self-contained auth/ package)"
}

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

# Adds azure-cli devcontainer feature for `az login` inside the container.
_inject_azure_cli_feature() {
  local devcontainer="$1"
  local tpl_dir="$2"

  [[ -f "$devcontainer" ]] || return 0
  grep -Fq 'azure-cli' "$devcontainer" && return 0

  if grep -Fq '"features"' "$devcontainer"; then
    local close_line
    close_line="$(awk '/"features"/{f=1} f && /\}/{print NR; exit}' "$devcontainer")"
    if [[ -n "$close_line" ]]; then
      local prev_line=$((close_line - 1))
      if ! sed -n "${prev_line}p" "$devcontainer" | grep -q ',$'; then
        sed -i "${prev_line}s/}$/},/" "$devcontainer"
        sed -i "${prev_line}s/\"\$/\",/" "$devcontainer"
      fi
      sed -i "${close_line}i\\    \"ghcr.io/devcontainers/features/azure-cli:1\": {}" "$devcontainer"
    fi
  else
    local insert_line
    insert_line="$(grep -n '"customizations"' "$devcontainer" | head -n1 | cut -d: -f1)"
    if [[ -z "$insert_line" ]]; then
      insert_line="$(grep -n '^}' "$devcontainer" | tail -n1 | cut -d: -f1)"
    fi
    if [[ -n "$insert_line" ]]; then
      local features_tmp; features_tmp="$(make_temp)"
      cp "$tpl_dir/fragments/devcontainer-features-azure.jsonc" "$features_tmp"
      sed -i 's/\r$//' "$features_tmp"
      sed -i "$((insert_line - 1))r ${features_tmp}" "$devcontainer"
    fi
  fi
}

# Injects az login check into post-create.sh before "Environment ready".
_inject_az_login_check() {
  local post_create="$1"
  local tpl_dir="$2"

  [[ -f "$post_create" ]] || return 0
  grep -Fq 'az account show' "$post_create" && return 0

  if grep -q '==> Environment ready' "$post_create"; then
    local pronto_line
    pronto_line="$(grep -Fn '==> Environment ready' "$post_create" | head -n1 | cut -d: -f1)"
    if [[ -n "$pronto_line" ]]; then
      local check_tmp; check_tmp="$(make_temp)"
      cp "$tpl_dir/fragments/post-create-check-az.sh" "$check_tmp"
      sed -i 's/\r$//' "$check_tmp"
      sed -i "$((pronto_line - 1))r ${check_tmp}" "$post_create"
    fi
  else
    warn "Anchor 'Environment ready' not found in post-create.sh -- az login check not injected"
  fi
}

# Copies unit tests for auth module.
_inject_identity_tests() {
  local project_path="$1"
  local package_name="$2"
  local has_src="$3"
  local tpl_dir="$4"

  local tests_dir="${project_path}/tests/unit"
  mkdir -p "$tests_dir"
  [[ -f "${tests_dir}/__init__.py" ]] || touch "${tests_dir}/__init__.py"

  local test_file="${tests_dir}/test_auth.py"
  [[ -f "$test_file" ]] && return 0

  render_template "$tpl_dir/templates/tests/unit/test_auth.py" "$test_file"

  if [[ "$has_src" == true ]]; then
    local sed_safe_prefix; sed_safe_prefix="$(_sed_escape "${package_name}.")"
    sed -i "s|import auth\\.credential as mod|import ${sed_safe_prefix}auth.credential as mod|" "$test_file"
  fi
}

# Injects Authentication section into README.md.
_inject_identity_readme() {
  local project_path="$1"
  local tpl_dir="$2"
  local pkg_prefix="$3"

  local readme="${project_path}/README.md"
  [[ -f "$readme" ]] || return 0

  grep -Fq 'Authentication (Azure Identity)' "$readme" && return 0

  local section_tmp; section_tmp="$(make_temp)"
  render_template "${tpl_dir}/fragments/readme-auth.md" "$section_tmp" "PKG_PREFIX=${pkg_prefix}"
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

  if ! grep -Fq '# Auth (Azure' "$readme"; then
    if grep -Fq 'Source code' "$readme"; then
      sed -i '/Source code/i\├── auth/                   # Auth (Azure credential, CLI inspector, opt-in router/ui)' "$readme"
    elif grep -Fq 'Entry point' "$readme"; then
      sed -i '/Entry point/i\├── auth/                   # Auth (Azure credential, CLI inspector, opt-in router/ui)' "$readme"
    fi
  fi
}
