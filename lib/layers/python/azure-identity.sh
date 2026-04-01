#!/usr/bin/env bash
# lib/layers/python/azure-identity.sh — Layer: Azure Identity
# Adds DefaultAzureCredential, auth/ package, health check, and /api/identity endpoint.

[[ -n "${_AZURE_IDENTITY_SH_LOADED:-}" ]] && return 0
_AZURE_IDENTITY_SH_LOADED=1

_LAYER_PHASE="infra"
_LAYER_CONFLICTS=""
_LAYER_REQUIRES=""

apply_layer_azure_identity() {
  local project_path="$1"
  local name="${2:-my-project}"
  local devcontainer_dir="${4:-${project_path}/.devcontainer}"

  log "Applying layer: azure-identity (DefaultAzureCredential)"

  local package_name; package_name="$(_to_package_name "$name")"
  _detect_python_layout "$project_path" "$package_name"
  local has_src="$_HAS_SRC"
  local pkg_base="$_PKG_BASE"
  local has_async_api="$_HAS_API_FRAMEWORK"

  local tpl_dir; tpl_dir="$(find_layer_templates_dir "python" "azure-identity")"

  # ---- requirements.txt ----
  inject_fragment "${tpl_dir}/fragments/requirements.txt" "${project_path}/requirements.txt"

  # ---- Idempotency: if auth/ already exists, skip generation ----
  if [[ -d "${pkg_base}/auth" ]]; then
    log "Directory auth/ already exists -- skipping code generation"
    echo "  Layer:    azure-identity [already applied]"
    return 0
  fi

  # ---- Create auth/ package ----
  mkdir -p "${pkg_base}/auth"
  render_template "$tpl_dir/templates/auth/__init__.py" "${pkg_base}/auth/__init__.py"
  render_template "$tpl_dir/templates/auth/credential.py" "${pkg_base}/auth/credential.py"

  # ---- .env.example ----
  ensure_env_example "$project_path"
  inject_fragment "${tpl_dir}/fragments/env.example" "${project_path}/.env.example"

  # ---- devcontainer: add azure-cli feature ----
  _inject_azure_cli_feature "${devcontainer_dir}/devcontainer.json"

  # ---- post-create.sh: az login check before "Environment ready" ----
  _inject_az_login_check "${devcontainer_dir}/post-create.sh" "$tpl_dir"

  # ---- main.py: standalone vs API ----
  if $has_async_api; then
    _inject_identity_api "$project_path" "$package_name" "$has_src" "$tpl_dir"
  else
    _inject_identity_standalone "$project_path" "$package_name" "$has_src" "$tpl_dir"
  fi

  # ---- Unit tests ----
  _inject_identity_tests "$project_path" "$package_name" "$has_src" "$tpl_dir"

  # ---- conftest: requires_azure fixture (auto-skip without credentials) ----
  local conftest="${project_path}/tests/conftest.py"
  if [[ -f "$conftest" ]] && ! grep -Fq 'requires_azure' "$conftest"; then
    inject_fragment_at "${tpl_dir}/fragments/conftest-fixture-azure.py" "$conftest" "fixtures"
  fi

  # ---- README.md ----
  _inject_identity_readme "$project_path" "$tpl_dir"

  echo "  Layer:    azure-identity (DefaultAzureCredential)"
}

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

# Adds azure-cli devcontainer feature for `az login` inside the container.
_inject_azure_cli_feature() {
  local devcontainer="$1"

  [[ -f "$devcontainer" ]] || return 0
  grep -Fq 'azure-cli' "$devcontainer" && return 0

  # Check if "features" key already exists
  if grep -Fq '"features"' "$devcontainer"; then
    # Find closing } of features block and insert before it
    local close_line
    close_line="$(awk '/"features"/{f=1} f && /\}/{print NR; exit}' "$devcontainer")"
    if [[ -n "$close_line" ]]; then
      # Add comma to previous line if needed
      local prev_line=$((close_line - 1))
      if ! sed -n "${prev_line}p" "$devcontainer" | grep -q ',$'; then
        sed -i "${prev_line}s/}$/},/" "$devcontainer"
        sed -i "${prev_line}s/\"\$/\",/" "$devcontainer"
      fi
      sed -i "${close_line}i\\    \"ghcr.io/devcontainers/features/azure-cli:1\": {}" "$devcontainer"
    fi
  else
    # No features key — insert before "customizations"
    local insert_line
    insert_line="$(grep -n '"customizations"' "$devcontainer" | head -n1 | cut -d: -f1)"
    if [[ -z "$insert_line" ]]; then
      # Fallback: insert before last }
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

# Injects auth imports, health check, and /api/identity route into FastAPI main.py.
_inject_identity_api() {
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

  # Idempotency: already has credential imports
  if grep -Fq 'credential_health' "$main_py"; then
    return 0
  fi

  local import_prefix=""
  if [[ "$has_src" == true ]]; then
    import_prefix="${package_name}."
  fi

  # ---- Import auth module ----
  local fastapi_import
  fastapi_import="$(grep -n 'from fastapi import' "$main_py" | head -n1 | cut -d: -f1)"
  if [[ -n "$fastapi_import" ]]; then
    local auth_import_tmp; auth_import_tmp="$(make_temp)"
    render_template "$tpl_dir/fragments/main-import-auth.py" "$auth_import_tmp" "IMPORT_PREFIX=${import_prefix}"
    sed -i "${fastapi_import}r ${auth_import_tmp}" "$main_py"
  fi

  # ---- Health check ----
  _inject_identity_health "$main_py" "$tpl_dir"

  # ---- /api/identity route ----
  if ! grep -Fq '/api/identity' "$main_py"; then
    local routes_tmp; routes_tmp="$(make_temp)"
    cp "$tpl_dir/fragments/main-routes-identity.py" "$routes_tmp"
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

# Replaces standalone main.py with credential verification + token inspection.
_inject_identity_standalone() {
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

  # Idempotency: already has credential import
  if grep -Fq 'credential_health' "$main_py"; then
    return 0
  fi

  render_template "$tpl_dir/templates/main.py" "$main_py"

  # Fix import path for src layout
  if [[ "$has_src" == true ]]; then
    local sed_safe_prefix; sed_safe_prefix="$(_sed_escape "${package_name}.")"
    sed -i "s|from auth\\.credential import|from ${sed_safe_prefix}auth.credential import|" "$main_py"
  fi
}

# Injects health check into main.py using marker or fallback.
_inject_identity_health() {
  local main_py="$1"
  local tpl_dir="$2"

  [[ -f "$main_py" ]] || return 0
  grep -Fq 'health_status["azure_identity"]' "$main_py" && return 0

  local marker_line
  marker_line="$(grep -Fn '# -- dropwsl:health-checks --' "$main_py" | head -n1 | cut -d: -f1)"
  if [[ -n "$marker_line" ]]; then
    local health_tmp; health_tmp="$(make_temp)"
    cp "$tpl_dir/fragments/main-health-identity.py" "$health_tmp"
    sed -i 's/\r$//' "$health_tmp"
    sed -i "${marker_line}r ${health_tmp}" "$main_py"
  else
    # Fallback: replace return {"status": "ok"} with extended version
    local return_line
    return_line="$(grep -Fn 'return {"status": "ok"}' "$main_py" | head -n1 | cut -d: -f1)"
    if [[ -n "$return_line" ]]; then
      local fallback_tmp; fallback_tmp="$(make_temp)"
      cp "$tpl_dir/fragments/main-health-identity-fallback.py" "$fallback_tmp"
      sed -i 's/\r$//' "$fallback_tmp"
      sed -i "${return_line}r ${fallback_tmp}" "$main_py"
      sed -i "${return_line}d" "$main_py"
    fi
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
  [[ -f "${project_path}/tests/unit/__init__.py" ]] || touch "${project_path}/tests/unit/__init__.py"

  local test_file="${tests_dir}/test_auth.py"
  [[ -f "$test_file" ]] && return 0

  render_template "$tpl_dir/templates/tests/unit/test_auth.py" "$test_file"

  # Fix import path for src layout
  if [[ "$has_src" == true ]]; then
    local sed_safe_prefix; sed_safe_prefix="$(_sed_escape "${package_name}.")"
    sed -i "s|import auth\\.credential as mod|import ${sed_safe_prefix}auth.credential as mod|" "$test_file"
  fi
}

# Injects Authentication section into README.md.
_inject_identity_readme() {
  local project_path="$1"
  local tpl_dir="$2"

  local readme="${project_path}/README.md"
  [[ -f "$readme" ]] || return 0

  # Idempotency
  grep -Fq 'Authentication (Azure Identity)' "$readme" && return 0

  local section_tmp; section_tmp="$(make_temp)"
  cp "$tpl_dir/fragments/readme-auth.md" "$section_tmp"
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

  # Update structure tree — add auth/
  if ! grep -Fq '# Auth (Azure' "$readme"; then
    if grep -Fq 'Source code' "$readme"; then
      sed -i '/Source code/i\├── auth/                   # Auth (Azure credential, health check)' "$readme"
    elif grep -Fq 'Entry point' "$readme"; then
      sed -i '/Entry point/i\├── auth/                   # Auth (Azure credential, health check)' "$readme"
    fi
  fi
}
