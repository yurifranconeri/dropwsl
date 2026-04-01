#!/usr/bin/env bash
# lib/layers/python/testcontainers.sh — Testcontainers (integration tests with real DB)
# Adds pytest fixtures with ephemeral PostgreSQL via testcontainers.

[[ -n "${_TESTCONTAINERS_SH_LOADED:-}" ]] && return 0
_TESTCONTAINERS_SH_LOADED=1

_LAYER_PHASE="test"
_LAYER_CONFLICTS=""
_LAYER_REQUIRES="postgres"

apply_layer_testcontainers() {
  local project_path="$1"
  local name="${2:-my-project}"

  log "Applying layer: testcontainers (Ephemeral PostgreSQL for tests)"

  local package_name; package_name="$(_to_package_name "$name")"
  _detect_python_layout "$project_path" "$package_name"
  local has_src="$_HAS_SRC"
  local has_api_framework="$_HAS_API_FRAMEWORK"
  local pkg_base="$_PKG_BASE"

  # ---- Detect db/ (artifact, not layer name) ----
  if [[ ! -d "${pkg_base}/db" ]]; then
    die "testcontainers: directory db/ not found -- use --with postgres,testcontainers"
  fi

  # ---- requirements-dev.txt ----
  local tpl_dir; tpl_dir="$(find_layer_templates_dir "python" "testcontainers")"
  inject_fragment "${tpl_dir}/fragments/requirements-dev.txt" "${project_path}/requirements-dev.txt"

  # ---- pytest markers em pyproject.toml ----
  if [[ -f "${project_path}/pyproject.toml" ]]; then
    if ! grep -Fq 'integration' "${project_path}/pyproject.toml"; then
      # Inject markers in pytest section
      if grep -Fq '[tool.pytest.ini_options]' "${project_path}/pyproject.toml"; then
        local markers_line
        markers_line="$(grep -n '^\[tool\.pytest\.ini_options\]' "${project_path}/pyproject.toml" | head -n1 | cut -d: -f1)"
        if [[ -n "$markers_line" ]]; then
          local markers_tmp
          markers_tmp="$(make_temp)"
          head -n "$markers_line" "${project_path}/pyproject.toml" > "$markers_tmp"
          local tpl_dir_tc; tpl_dir_tc="$(find_layer_templates_dir "python" "testcontainers")"
          cat "$tpl_dir_tc/fragments/pyproject-markers.toml" >> "$markers_tmp"
          tail -n "+$((markers_line + 1))" "${project_path}/pyproject.toml" >> "$markers_tmp"
          mv "$markers_tmp" "${project_path}/pyproject.toml"
        fi
      fi
    fi
  fi

  # ---- conftest.py (fixtures com testcontainers) — tests/integration/ ----

  local integ_dir="${project_path}/tests/integration"

  if [[ -f "${integ_dir}/conftest.py" ]] && grep -Fq 'testcontainers' "${integ_dir}/conftest.py"; then
    echo "  Layer:    testcontainers (Ephemeral PostgreSQL) [already applied]"
    return 0
  fi

  mkdir -p "$integ_dir"
  [[ -f "${integ_dir}/__init__.py" ]] || touch "${integ_dir}/__init__.py"

  local import_prefix=""
  if [[ "$has_src" == true ]]; then
    import_prefix="${package_name}."
  fi

  local tpl_dir; tpl_dir="$(find_layer_templates_dir "python" "testcontainers")"

  if $has_api_framework; then
    local patch_target="${import_prefix}main.engine"
    render_template "$tpl_dir/templates/tests/conftest_fastapi.py" "${integ_dir}/conftest.py" \
      "IMPORT_PREFIX=${import_prefix}" "PATCH_TARGET=${patch_target}"
  else
    render_template "$tpl_dir/templates/tests/conftest_standalone.py" "${integ_dir}/conftest.py" \
      "IMPORT_PREFIX=${import_prefix}"
  fi

  # ---- Integration tests (tests/integration/) ----
  local test_integration="${integ_dir}/test_integration.py"
  if [[ ! -f "$test_integration" ]]; then
    render_template "$tpl_dir/templates/tests/test_integration.py" "$test_integration" "IMPORT_PREFIX=${import_prefix}"
  fi

  # ---- Smoke tests (tests/smoke/) ----
  local smoke_dir="${project_path}/tests/smoke"
  mkdir -p "$smoke_dir"
  [[ -f "${smoke_dir}/__init__.py" ]] || touch "${smoke_dir}/__init__.py"

  local test_smoke="${smoke_dir}/test_smoke.py"
  if [[ ! -f "$test_smoke" ]]; then
    if $has_api_framework; then
      render_template "$tpl_dir/templates/tests/test_smoke_fastapi.py" "$test_smoke"
    else
      render_template "$tpl_dir/templates/tests/test_smoke.py" "$test_smoke"
    fi
  fi

  # ---- README.md — update Tests section with integration/smoke ----
  local readme="${project_path}/README.md"
  if [[ -f "$readme" ]] && ! grep -Fq 'integration' "$readme"; then
    local test_section="
### Integration tests (testcontainers)

Integration tests use an ephemeral PostgreSQL via [testcontainers](https://testcontainers.com/).
Requires Docker accessible.

\`\`\`bash
# Run integration tests (ephemeral real database)
pytest -m integration

# Run smoke tests (connectivity)
pytest -m smoke

# Run ALL tests (unit + integration + smoke)
pytest
\`\`\`
"
    if grep -q '^## Lint' "$readme"; then
      local lint_line
      lint_line="$(grep -n '^## Lint' "$readme" | head -n1 | cut -d: -f1)"
      local tmp
      tmp="$(make_temp)"
      head -n "$((lint_line - 1))" "$readme" > "$tmp"
      echo "$test_section" >> "$tmp"
      tail -n "+${lint_line}" "$readme" >> "$tmp"
      mv "$tmp" "$readme"
    else
      echo "$test_section" >> "$readme"
    fi
  fi

  echo "  Layer:    testcontainers (Ephemeral PostgreSQL for tests)"
}
