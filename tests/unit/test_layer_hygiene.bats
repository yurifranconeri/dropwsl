#!/usr/bin/env bats
# tests/unit/test_layer_hygiene.bats — Invariant tests to prevent regression
# Validates: zero heredocs, zero cross-layer naming, guard clauses, fragment existence.
#
# These tests scan the actual source files in lib/layers/ and enforce structural
# rules that prevent SRP violations and coupling between layers.

setup() {
  load '../helpers/test_helper'
  _common_setup
}

teardown() {
  _common_teardown
}

# ── Zero heredocs in lib/layers/ ──────────────────────────────────

@test "hygiene: zero heredocs in lib/layers/" {
  local matches
  matches="$(grep -rn '<<' "${REPO_ROOT}/lib/layers/" 2>/dev/null || true)"
  if [[ -n "$matches" ]]; then
    echo "Heredocs found in lib/layers/:" >&2
    echo "$matches" >&2
    fail "lib/layers/ must have zero heredocs — use templates/fragments instead"
  fi
}

# ── Guard clause on every layer .sh ──────────────────────────────

@test "hygiene: every layer .sh has guard clause" {
  local failures=""
  local layer_file
  while IFS= read -r layer_file; do
    # Guard clause: [[ -n "${_NAME_LOADED:-}" ]] && return 0
    if ! grep -q '_[A-Z_]*_LOADED:-' "$layer_file"; then
      failures+="  MISSING guard clause: ${layer_file#${REPO_ROOT}/}\n"
    fi
  done < <(find "${REPO_ROOT}/lib/layers" -name '*.sh' -type f)

  if [[ -n "$failures" ]]; then
    echo -e "$failures" >&2
    fail "All layer .sh files must have guard clause"
  fi
}

# ── Every layer .sh has _LAYER_PHASE metadata ────────────────────

@test "hygiene: every layer .sh declares _LAYER_PHASE" {
  local failures=""
  local layer_file
  while IFS= read -r layer_file; do
    local basename
    basename="$(basename "$layer_file")"
    # agent-helpers.sh is not a layer — skip
    [[ "$basename" == "agent-helpers.sh" ]] && continue
    if ! grep -q '_LAYER_PHASE=' "$layer_file"; then
      failures+="  MISSING _LAYER_PHASE: ${layer_file#${REPO_ROOT}/}\n"
    fi
  done < <(find "${REPO_ROOT}/lib/layers" -name '*.sh' -type f)

  if [[ -n "$failures" ]]; then
    echo -e "$failures" >&2
    fail "All layer .sh files (except agent-helpers.sh) must declare _LAYER_PHASE"
  fi
}

# ── No cross-layer naming: layer .sh must not reference other layer names ────

@test "hygiene: no layer references another layer by explicit name in variables" {
  # Forbidden patterns: variables that encode knowledge of another layer's name
  # e.g. has_fastapi, has_streamlit, has_postgres, has_redis, has_locust, has_testcontainers
  # Allowed: has_api_framework, has_async_api, has_compose, has_src, has_app_service
  local forbidden_vars='has_fastapi|has_streamlit|has_postgres|has_redis|has_locust|has_testcontainers|has_mypy|has_uv|has_gitleaks|has_semgrep|has_trivy|has_compose_layer'
  local failures=""
  local layer_file
  while IFS= read -r layer_file; do
    local basename
    basename="$(basename "$layer_file" .sh)"
    local matches
    matches="$(grep -nE "$forbidden_vars" "$layer_file" 2>/dev/null || true)"
    if [[ -n "$matches" ]]; then
      # Filter out: a layer IS allowed to reference itself (e.g. fastapi.sh can have patterns about fastapi)
      local line
      while IFS= read -r line; do
        # Check if this line references a DIFFERENT layer
        local is_self=false
        case "$basename" in
          fastapi)        echo "$line" | grep -qE 'has_fastapi' && is_self=true ;;
          streamlit)      echo "$line" | grep -qE 'has_streamlit' && is_self=true ;;
          postgres)       echo "$line" | grep -qE 'has_postgres' && is_self=true ;;
          redis)          echo "$line" | grep -qE 'has_redis' && is_self=true ;;
          locust)         echo "$line" | grep -qE 'has_locust' && is_self=true ;;
          testcontainers) echo "$line" | grep -qE 'has_testcontainers' && is_self=true ;;
          mypy)           echo "$line" | grep -qE 'has_mypy' && is_self=true ;;
          uv)             echo "$line" | grep -qE 'has_uv' && is_self=true ;;
          gitleaks)       echo "$line" | grep -qE 'has_gitleaks' && is_self=true ;;
          semgrep)        echo "$line" | grep -qE 'has_semgrep' && is_self=true ;;
          trivy)          echo "$line" | grep -qE 'has_trivy' && is_self=true ;;
        esac
        if [[ "$is_self" == false ]]; then
          failures+="  ${layer_file#${REPO_ROOT}/}: ${line}\n"
        fi
      done <<< "$matches"
    fi
  done < <(find "${REPO_ROOT}/lib/layers" -name '*.sh' -type f)

  if [[ -n "$failures" ]]; then
    echo -e "Cross-layer naming violations:\n$failures" >&2
    fail "Layers must not reference other layers by name in variables"
  fi
}

@test "hygiene: no layer function names encode another layer's name" {
  # Function names like _inject_redis_fastapi are forbidden
  # Allowed: _inject_redis_api, _inject_postgres_into_api
  local failures=""
  local layer_file
  while IFS= read -r layer_file; do
    local basename
    basename="$(basename "$layer_file" .sh)"
    # Find function declarations
    local func_names
    func_names="$(grep -oE '[a-z_]+\(\)' "$layer_file" 2>/dev/null | sed 's/()//' || true)"
    [[ -z "$func_names" ]] && continue
    local func
    while IFS= read -r func; do
      # Check if function name contains a DIFFERENT layer's name
      local other_layers="fastapi streamlit postgres redis locust testcontainers mypy uv gitleaks semgrep trivy"
      local other
      for other in $other_layers; do
        [[ "$other" == "$basename" ]] && continue
        if echo "$func" | grep -qw "$other"; then
          failures+="  ${layer_file#${REPO_ROOT}/}: function '${func}' references layer '${other}'\n"
        fi
      done
    done <<< "$func_names"
  done < <(find "${REPO_ROOT}/lib/layers" -name '*.sh' -type f)

  if [[ -n "$failures" ]]; then
    echo -e "Cross-layer function naming violations:\n$failures" >&2
    fail "Layer functions must not encode other layer names"
  fi
}

# ── Fragment/template file references exist on disk ──────────────

@test "hygiene: all find_layer_templates_dir scopes have corresponding directories" {
  # Extract all find_layer_templates_dir calls and verify each directory exists
  local failures=""
  local layer_file
  while IFS= read -r layer_file; do
    local calls
    calls="$(grep -oE 'find_layer_templates_dir "[^"]+" "[^"]+"' "$layer_file" 2>/dev/null || true)"
    [[ -z "$calls" ]] && continue
    while IFS= read -r call; do
      local scope layer_name
      scope="$(echo "$call" | sed 's/find_layer_templates_dir "\([^"]*\)" "\([^"]*\)"/\1/')"
      layer_name="$(echo "$call" | sed 's/find_layer_templates_dir "\([^"]*\)" "\([^"]*\)"/\2/')"
      local expected_dir="${REPO_ROOT}/templates/layers/${scope}/${layer_name}"
      if [[ ! -d "$expected_dir" ]]; then
        failures+="  ${layer_file#${REPO_ROOT}/}: references '${scope}/${layer_name}' but ${expected_dir#${REPO_ROOT}/} not found\n"
      fi
    done <<< "$calls"
  done < <(find "${REPO_ROOT}/lib/layers" -name '*.sh' -type f)

  if [[ -n "$failures" ]]; then
    echo -e "Missing template directories:\n$failures" >&2
    fail "All find_layer_templates_dir references must have corresponding directories"
  fi
}

@test "hygiene: every render_template/inject_fragment source file exists" {
  # Scan for render_template and inject_fragment calls that reference $tpl_dir paths
  # This test verifies the most common pattern: "$tpl_dir/templates/*" and "$tpl_dir/fragments/*"
  local failures=""
  local layer_file
  while IFS= read -r layer_file; do
    # Find all string references to templates/ and fragments/ subdirs
    local refs
    refs="$(grep -oE '\$\{?tpl_dir[a-z_]*\}?/(templates|fragments)/[^ "]+' "$layer_file" 2>/dev/null || true)"
    [[ -z "$refs" ]] && continue

    # Resolve the tpl_dir for this layer
    local scope="" layer_name=""
    local tpl_call
    tpl_call="$(grep -m1 'find_layer_templates_dir' "$layer_file" 2>/dev/null || true)"
    if [[ -n "$tpl_call" ]]; then
      scope="$(echo "$tpl_call" | grep -oE 'find_layer_templates_dir "[^"]+" "[^"]+"' | sed 's/find_layer_templates_dir "\([^"]*\)" "\([^"]*\)"/\1/' || true)"
      layer_name="$(echo "$tpl_call" | grep -oE 'find_layer_templates_dir "[^"]+" "[^"]+"' | sed 's/find_layer_templates_dir "\([^"]*\)" "\([^"]*\)"/\2/' || true)"
    fi
    [[ -z "$scope" || -z "$layer_name" ]] && continue

    local base_dir="${REPO_ROOT}/templates/layers/${scope}/${layer_name}"
    while IFS= read -r ref; do
      # Strip variable prefix to get relative path
      local rel_path
      rel_path="$(echo "$ref" | sed -E 's|\$\{?tpl_dir[a-z_]*\}?/||')"
      local full_path="${base_dir}/${rel_path}"
      # Strip trailing quote or paren if any
      full_path="${full_path%%\"*}"
      full_path="${full_path%%\'*}"
      if [[ ! -f "$full_path" ]]; then
        failures+="  ${layer_file#${REPO_ROOT}/}: references '${rel_path}' but file not found at ${full_path#${REPO_ROOT}/}\n"
      fi
    done <<< "$refs"
  done < <(find "${REPO_ROOT}/lib/layers" -name '*.sh' -type f)

  if [[ -n "$failures" ]]; then
    echo -e "Missing template/fragment files:\n$failures" >&2
    fail "All render_template/inject_fragment source files must exist on disk"
  fi
}

# ── No direct use of 'exit' in layer modules ─────────────────────

@test "hygiene: no layer .sh uses 'exit' (must use 'return' or 'die')" {
  local failures=""
  local layer_file
  while IFS= read -r layer_file; do
    # Match lines with 'exit' as a command (not in comments, not in 'exit code' text)
    local hits
    hits="$(grep -nE '^\s*exit\s' "$layer_file" 2>/dev/null || true)"
    if [[ -n "$hits" ]]; then
      failures+="  ${layer_file#${REPO_ROOT}/}:\n${hits}\n"
    fi
  done < <(find "${REPO_ROOT}/lib/layers" -name '*.sh' -type f)

  if [[ -n "$failures" ]]; then
    echo -e "Direct 'exit' in layer modules (must use return/die):\n$failures" >&2
    fail "Layer modules must not use 'exit' — use 'return' or 'die()'"
  fi
}

# ── No direct 'curl' usage (must use curl_retry) ─────────────────

@test "hygiene: no layer .sh uses curl directly (must use curl_retry)" {
  local failures=""
  local layer_file
  while IFS= read -r layer_file; do
    # Match 'curl ' but not 'curl_retry'
    local hits
    hits="$(grep -nE '\bcurl\s' "$layer_file" 2>/dev/null | grep -v 'curl_retry' | grep -v '^[[:space:]]*#' || true)"
    if [[ -n "$hits" ]]; then
      failures+="  ${layer_file#${REPO_ROOT}/}:\n${hits}\n"
    fi
  done < <(find "${REPO_ROOT}/lib/layers" -name '*.sh' -type f)

  if [[ -n "$failures" ]]; then
    echo -e "Direct 'curl' usage (must use curl_retry):\n$failures" >&2
    fail "Layer modules must not use 'curl' directly — use curl_retry"
  fi
}

# ── No set -euo pipefail in layer modules ─────────────────────────

@test "hygiene: no layer .sh uses 'set -euo pipefail' (only dropwsl.sh)" {
  local failures=""
  local layer_file
  while IFS= read -r layer_file; do
    local hits
    hits="$(grep -nE '^\s*set\s+-[euo]' "$layer_file" 2>/dev/null || true)"
    if [[ -n "$hits" ]]; then
      failures+="  ${layer_file#${REPO_ROOT}/}:\n${hits}\n"
    fi
  done < <(find "${REPO_ROOT}/lib/layers" -name '*.sh' -type f)

  if [[ -n "$failures" ]]; then
    echo -e "'set -euo pipefail' in layer modules:\n$failures" >&2
    fail "Layer modules must not use 'set -euo pipefail' — only dropwsl.sh"
  fi
}

# ── Marker format consistency in templates ────────────────────────

@test "hygiene: all dropwsl markers in templates use 'dropwsl:<section>' (no space after colon)" {
  # Correct:   # -- dropwsl:imports --
  # Forbidden: # -- dropwsl: imports --  (space after colon)
  local failures=""
  local tpl_file
  while IFS= read -r tpl_file; do
    local hits
    hits="$(grep -nE 'dropwsl:\s+' "$tpl_file" 2>/dev/null || true)"
    if [[ -n "$hits" ]]; then
      failures+="  ${tpl_file#${REPO_ROOT}/}:\n${hits}\n"
    fi
  done < <(find "${REPO_ROOT}/templates" -type f \( -name '*.py' -o -name '*.toml' -o -name '*.yaml' -o -name '*.yml' -o -name '*.sh' \))

  if [[ -n "$failures" ]]; then
    echo -e "Markers with space after colon:\n$failures" >&2
    fail "All dropwsl markers must use 'dropwsl:<section>' (no space after colon)"
  fi
}

# ── sed targeting markers must match actual template markers ──────

@test "hygiene: every sed marker pattern in layers matches a real template marker" {
  # Collect all markers defined in templates
  local template_markers
  template_markers="$(grep -rhoE 'dropwsl:[a-z_-]+' "${REPO_ROOT}/templates/" 2>/dev/null | sort -u)"

  local failures=""
  local layer_file
  while IFS= read -r layer_file; do
    # Find sed commands that target dropwsl: markers
    local sed_markers
    sed_markers="$(grep -oE 'dropwsl:[a-z_-]+' "$layer_file" 2>/dev/null | sort -u || true)"
    [[ -z "$sed_markers" ]] && continue
    local marker
    while IFS= read -r marker; do
      if ! echo "$template_markers" | grep -Fxq "$marker"; then
        failures+="  ${layer_file#${REPO_ROOT}/}: references '${marker}' but no template defines it\n"
      fi
    done <<< "$sed_markers"
  done < <(find "${REPO_ROOT}/lib/layers" -name '*.sh' -type f)

  if [[ -n "$failures" ]]; then
    echo -e "Orphan marker references:\n$failures" >&2
    fail "Every dropwsl marker used in layers must exist in a template"
  fi
}

# ── inject_fragment_at sections exist in conftest template ────────

@test "hygiene: every inject_fragment_at section has matching marker in conftest template" {
  local conftest_tpl="${REPO_ROOT}/templates/devcontainer/python/tests/conftest.py"
  [[ -f "$conftest_tpl" ]] || skip "conftest template not found"

  local failures=""
  local layer_file
  while IFS= read -r layer_file; do
    # Extract section names from inject_fragment_at calls: 3rd positional arg (quoted string)
    local sections
    sections="$(grep -oE 'inject_fragment_at\s+[^ ]+\s+[^ ]+\s+"([^"]+)"' "$layer_file" 2>/dev/null \
      | sed -E 's/.*"([^"]+)"/\1/' || true)"
    [[ -z "$sections" ]] && continue
    local section
    while IFS= read -r section; do
      local marker="# -- dropwsl:${section} --"
      if ! grep -Fq "$marker" "$conftest_tpl"; then
        failures+="  ${layer_file#${REPO_ROOT}/}: inject_fragment_at section '${section}' but conftest has no '${marker}'\n"
      fi
    done <<< "$sections"
  done < <(find "${REPO_ROOT}/lib/layers" -name '*.sh' -type f)

  if [[ -n "$failures" ]]; then
    echo -e "Missing markers in conftest template:\n$failures" >&2
    fail "Every inject_fragment_at section must have a matching marker in the conftest template"
  fi
}

# ── No forbidden multi-line sed patterns (regression prevention) ──

@test "hygiene: no sed with inline \\n in substitution (use make_temp + sed r)" {
  # Forbidden: sed -i '/pattern/a text\nmore'  or  sed -i 's|...|...\n...|'
  # These cause silent corruption. See copilot-instructions.md regression rules.
  local failures=""
  local layer_file
  while IFS= read -r layer_file; do
    local hits
    # Match sed commands containing literal \n in the replacement part (not in comments)
    hits="$(grep -nE '^\s*sed\s.*\\n' "$layer_file" 2>/dev/null | grep -v '^\s*#' || true)"
    if [[ -n "$hits" ]]; then
      failures+="  ${layer_file#${REPO_ROOT}/}:\n${hits}\n"
    fi
  done < <(find "${REPO_ROOT}/lib/layers" -name '*.sh' -type f)

  if [[ -n "$failures" ]]; then
    echo -e "Forbidden sed with inline \\\\n:\n$failures" >&2
    fail "Never use \\n in sed substitutions — use make_temp + sed r instead"
  fi
}

# ── Core installer guard clauses ──────────────────────────────────

@test "hygiene: every lib/core/*.sh has guard clause" {
  local failures=""
  local core_file
  while IFS= read -r core_file; do
    if ! grep -q '_[A-Z_]*_LOADED:-' "$core_file"; then
      failures+="  MISSING guard clause: ${core_file#${REPO_ROOT}/}\n"
    fi
  done < <(find "${REPO_ROOT}/lib/core" -name '*.sh' -type f)

  if [[ -n "$failures" ]]; then
    echo -e "$failures" >&2
    fail "All lib/core/*.sh files must have guard clause"
  fi
}

# ── Core installer idempotency pattern ────────────────────────────

@test "hygiene: every install_* in lib/core/ checks before installing (has_cmd or version)" {
  # Each install_*() function should start with an idempotency check:
  # has_cmd, --version, dpkg -s, or similar early-return pattern.
  local failures=""
  local core_file
  while IFS= read -r core_file; do
    local basename
    basename="$(basename "$core_file" .sh)"
    # Skip non-installer files (e.g., systemd has configure_systemd, not install_)
    local func_name
    func_name="$(grep -oE '^install_[a-z_-]+\(\)' "$core_file" 2>/dev/null | head -n1 | sed 's/()//' || true)"
    [[ -z "$func_name" ]] && continue

    # Extract the function body (from declaration to next top-level function or EOF)
    local func_start func_body
    func_start="$(grep -n "^${func_name}()" "$core_file" | head -n1 | cut -d: -f1)"
    [[ -z "$func_start" ]] && continue
    # Get first 15 lines of the function body (enough for the guard)
    func_body="$(tail -n "+$((func_start + 1))" "$core_file" | head -n 15)"

    # Check for idempotency pattern: has_cmd, command -v, dpkg, --version, "already installed"
    if ! echo "$func_body" | grep -qE 'has_cmd|command -v|dpkg|--version|already.installed|is_installed'; then
      failures+="  ${core_file#${REPO_ROOT}/}: ${func_name}() lacks idempotency check\n"
    fi
  done < <(find "${REPO_ROOT}/lib/core" -name '*.sh' -type f)

  if [[ -n "$failures" ]]; then
    echo -e "Missing idempotency pattern:\n$failures" >&2
    fail "Every install_*() in lib/core/ must check before installing (has_cmd, --version, etc.)"
  fi
}
