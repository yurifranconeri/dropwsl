#!/usr/bin/env bash
# lib/layers/python/azure-ai-foundry.sh — Layer: Azure AI Foundry
# Adds AIProjectClient, foundry/ package, health check, and /api/foundry/status endpoint.

[[ -n "${_AZURE_AI_FOUNDRY_SH_LOADED:-}" ]] && return 0
_AZURE_AI_FOUNDRY_SH_LOADED=1

_LAYER_PHASE="infra"
_LAYER_CONFLICTS=""
_LAYER_REQUIRES="azure-identity"

apply_layer_azure_ai_foundry() {
  local project_path="$1"
  local name="${2:-my-project}"
  local devcontainer_dir="${4:-${project_path}/.devcontainer}"

  log "Applying layer: azure-ai-foundry (AIProjectClient)"

  local package_name; package_name="$(_to_package_name "$name")"
  _detect_python_layout "$project_path" "$package_name"
  local has_src="$_HAS_SRC"
  local pkg_base="$_PKG_BASE"
  local has_async_api="$_HAS_API_FRAMEWORK"

  local tpl_dir; tpl_dir="$(find_layer_templates_dir "python" "azure-ai-foundry")"

  # ---- requirements.txt ----
  inject_fragment "${tpl_dir}/fragments/requirements.txt" "${project_path}/requirements.txt"

  # ---- Idempotency: if foundry/ already exists, skip generation ----
  if [[ -d "${pkg_base}/foundry" ]]; then
    log "Directory foundry/ already exists -- skipping code generation"
    echo "  Layer:    azure-ai-foundry [already applied]"
    return 0
  fi

  # ---- Create foundry/ package ----
  mkdir -p "${pkg_base}/foundry"
  render_template "$tpl_dir/templates/foundry/__init__.py" "${pkg_base}/foundry/__init__.py"
  render_template "$tpl_dir/templates/foundry/client.py" "${pkg_base}/foundry/client.py"
  render_template "$tpl_dir/templates/foundry/models.py" "${pkg_base}/foundry/models.py"
  render_template "$tpl_dir/templates/foundry/connections.py" "${pkg_base}/foundry/connections.py"

  # ---- Fix import paths for src layout ----
  if [[ "$has_src" == true ]]; then
    local sed_safe_prefix; sed_safe_prefix="$(_sed_escape "${package_name}.")"
    sed -i "s|from auth\\.credential import|from ${sed_safe_prefix}auth.credential import|" "${pkg_base}/foundry/client.py"
    sed -i "s|from \\.client import|from ${sed_safe_prefix}foundry.client import|" "${pkg_base}/foundry/models.py"
    sed -i "s|from \\.client import|from ${sed_safe_prefix}foundry.client import|" "${pkg_base}/foundry/connections.py"
    sed -i "s|from \\.client import|from ${sed_safe_prefix}foundry.client import|" "${pkg_base}/foundry/__init__.py"
    sed -i "s|from \\.connections import|from ${sed_safe_prefix}foundry.connections import|" "${pkg_base}/foundry/__init__.py"
    sed -i "s|from \\.models import|from ${sed_safe_prefix}foundry.models import|" "${pkg_base}/foundry/__init__.py"
  fi

  # ---- .env.example ----
  ensure_env_example "$project_path"
  inject_fragment "${tpl_dir}/fragments/env.example" "${project_path}/.env.example"

  # ---- main.py: standalone vs API ----
  if $has_async_api; then
    _inject_foundry_api "$project_path" "$package_name" "$has_src" "$tpl_dir"
  else
    _inject_foundry_standalone "$project_path" "$package_name" "$has_src" "$tpl_dir"
  fi

  # ---- Unit tests ----
  _inject_foundry_tests "$project_path" "$package_name" "$has_src" "$tpl_dir"

  # ---- conftest: requires_foundry fixture (auto-skip without endpoint) ----
  local conftest="${project_path}/tests/conftest.py"
  if [[ -f "$conftest" ]] && ! grep -Fq 'requires_foundry' "$conftest"; then
    inject_fragment_at "${tpl_dir}/fragments/conftest-fixture-foundry.py" "$conftest" "fixtures"
  fi

  # ---- README.md ----
  _inject_foundry_readme "$project_path" "$tpl_dir"

  echo "  Layer:    azure-ai-foundry (AIProjectClient)"
}

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

# Injects foundry imports, health check, and /api/foundry/status route into FastAPI main.py.
_inject_foundry_api() {
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

  # Idempotency: already has foundry imports
  if grep -Fq 'foundry_health' "$main_py"; then
    return 0
  fi

  local import_prefix=""
  if [[ "$has_src" == true ]]; then
    import_prefix="${package_name}."
  fi

  # ---- Import foundry module ----
  # Insert after the last existing import block (after auth imports if present)
  local last_import_line
  last_import_line="$(grep -n '^from\|^import' "$main_py" | tail -n1 | cut -d: -f1)"
  if [[ -n "$last_import_line" ]]; then
    local foundry_import_tmp; foundry_import_tmp="$(make_temp)"
    render_template "$tpl_dir/fragments/main-import-foundry.py" "$foundry_import_tmp" "IMPORT_PREFIX=${import_prefix}"
    sed -i "${last_import_line}r ${foundry_import_tmp}" "$main_py"
  fi

  # ---- Health check ----
  _inject_foundry_health "$main_py" "$tpl_dir"

  # ---- /api/foundry/status route ----
  if ! grep -Fq '/api/foundry/status' "$main_py"; then
    local routes_tmp; routes_tmp="$(make_temp)"
    cp "$tpl_dir/fragments/main-routes-foundry.py" "$routes_tmp"
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

# Replaces standalone main.py with foundry connection verification.
_inject_foundry_standalone() {
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

  # Idempotency: already has foundry import
  if grep -Fq 'foundry_health' "$main_py"; then
    return 0
  fi

  render_template "$tpl_dir/templates/main.py" "$main_py"

  # Fix import paths for src layout
  if [[ "$has_src" == true ]]; then
    local sed_safe_prefix; sed_safe_prefix="$(_sed_escape "${package_name}.")"
    sed -i "s|from foundry\\.client import|from ${sed_safe_prefix}foundry.client import|" "$main_py"
    sed -i "s|from foundry\\.models import|from ${sed_safe_prefix}foundry.models import|" "$main_py"
    sed -i "s|from foundry\\.connections import|from ${sed_safe_prefix}foundry.connections import|" "$main_py"
  fi
}

# Injects health check into main.py using marker or fallback.
_inject_foundry_health() {
  local main_py="$1"
  local tpl_dir="$2"

  [[ -f "$main_py" ]] || return 0
  grep -Fq 'health_status["azure_foundry"]' "$main_py" && return 0

  local marker_line
  marker_line="$(grep -Fn '# -- dropwsl:health-checks --' "$main_py" | head -n1 | cut -d: -f1)"
  if [[ -n "$marker_line" ]]; then
    local health_tmp; health_tmp="$(make_temp)"
    cp "$tpl_dir/fragments/main-health-foundry.py" "$health_tmp"
    sed -i 's/\r$//' "$health_tmp"
    sed -i "${marker_line}r ${health_tmp}" "$main_py"
  else
    # Fallback: replace return {"status": "ok"} with extended version
    local return_line
    return_line="$(grep -Fn 'return {"status": "ok"}' "$main_py" | head -n1 | cut -d: -f1)"
    if [[ -n "$return_line" ]]; then
      local fallback_tmp; fallback_tmp="$(make_temp)"
      cp "$tpl_dir/fragments/main-health-foundry-fallback.py" "$fallback_tmp"
      sed -i 's/\r$//' "$fallback_tmp"
      sed -i "${return_line}r ${fallback_tmp}" "$main_py"
      sed -i "${return_line}d" "$main_py"
    fi
  fi
}

# Copies unit tests for foundry module.
_inject_foundry_tests() {
  local project_path="$1"
  local package_name="$2"
  local has_src="$3"
  local tpl_dir="$4"

  local tests_dir="${project_path}/tests/unit"
  mkdir -p "$tests_dir"
  [[ -f "${project_path}/tests/unit/__init__.py" ]] || touch "${project_path}/tests/unit/__init__.py"

  local test_file="${tests_dir}/test_foundry.py"
  [[ -f "$test_file" ]] && return 0

  render_template "$tpl_dir/templates/tests/unit/test_foundry.py" "$test_file"

  # Fix import path for src layout
  if [[ "$has_src" == true ]]; then
    local sed_safe_prefix; sed_safe_prefix="$(_sed_escape "${package_name}.")"
    sed -i "s|import foundry\\.client as client_mod|import ${sed_safe_prefix}foundry.client as client_mod|" "$test_file"
    sed -i "s|import foundry\\.models as models_mod|import ${sed_safe_prefix}foundry.models as models_mod|" "$test_file"
    sed -i "s|import foundry\\.connections as connections_mod|import ${sed_safe_prefix}foundry.connections as connections_mod|" "$test_file"
  fi
}

# Injects Azure AI Foundry section into README.md.
_inject_foundry_readme() {
  local project_path="$1"
  local tpl_dir="$2"

  local readme="${project_path}/README.md"
  [[ -f "$readme" ]] || return 0

  # Idempotency
  grep -Fq 'Azure AI Foundry' "$readme" && return 0

  local section_tmp; section_tmp="$(make_temp)"
  cp "$tpl_dir/fragments/readme-foundry.md" "$section_tmp"
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

  # Update structure tree — add foundry/
  if ! grep -Fq '# Foundry (Azure' "$readme"; then
    if grep -Fq 'Auth (Azure' "$readme"; then
      sed -i '/Auth (Azure/a\├── foundry/                # Foundry (Azure AI Projects client)' "$readme"
    elif grep -Fq 'Source code' "$readme"; then
      sed -i '/Source code/i\├── foundry/                # Foundry (Azure AI Projects client)' "$readme"
    elif grep -Fq 'Entry point' "$readme"; then
      sed -i '/Entry point/i\├── foundry/                # Foundry (Azure AI Projects client)' "$readme"
    fi
  fi
}
