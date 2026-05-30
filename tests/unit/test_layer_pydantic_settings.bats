#!/usr/bin/env bats
# tests/unit/test_layer_pydantic_settings.bats
# Pure structural / metadata checks for the pydantic-settings layer
# (no scaffold required).

setup() {
  load '../helpers/test_helper'
  _common_setup
  LAYER_FILE="${REPO_ROOT}/lib/layers/python/pydantic-settings.sh"
  TPL_DIR="${REPO_ROOT}/templates/layers/python/pydantic-settings"
}

teardown() {
  _common_teardown
}

@test "pydantic-settings: layer file exists" {
  assert [ -f "$LAYER_FILE" ]
}

@test "pydantic-settings: has guard clause" {
  grep -q '_PYDANTIC_SETTINGS_SH_LOADED' "$LAYER_FILE"
}

@test "pydantic-settings: declares _LAYER_PHASE=tooling" {
  grep -q '^_LAYER_PHASE="tooling"' "$LAYER_FILE"
}

@test "pydantic-settings: declares empty _LAYER_REQUIRES" {
  grep -q '^_LAYER_REQUIRES=""' "$LAYER_FILE"
}

@test "pydantic-settings: declares empty _LAYER_CONFLICTS" {
  grep -q '^_LAYER_CONFLICTS=""' "$LAYER_FILE"
}

@test "pydantic-settings: apply function defined" {
  grep -q '^apply_layer_pydantic_settings()' "$LAYER_FILE"
}

@test "pydantic-settings: no heredoc in layer file" {
  ! grep -q '<<' "$LAYER_FILE"
}

@test "pydantic-settings: layer does not detect other layers" {
  ! grep -E 'has_(fastapi|streamlit|postgres|redis|uv|mypy)|_HAS_API_FRAMEWORK' "$LAYER_FILE"
}

# ── Templates and fragments exist ────────────────────────────────

@test "pydantic-settings: all config/ templates exist" {
  assert [ -f "${TPL_DIR}/templates/config/__init__.py" ]
  assert [ -f "${TPL_DIR}/templates/config/__main__.py" ]
  assert [ -f "${TPL_DIR}/templates/config/settings.py" ]
  assert [ -f "${TPL_DIR}/templates/config/cli.py" ]
}

@test "pydantic-settings: unit test template exists" {
  assert [ -f "${TPL_DIR}/templates/tests/unit/test_config.py" ]
}

@test "pydantic-settings: all required fragments exist" {
  for frag in requirements.txt env.example readme-pydantic-settings.md; do
    assert [ -f "${TPL_DIR}/fragments/${frag}" ]
  done
}

# ── Fragments are LF-only (critical: dedup guard breaks on CRLF) ─

@test "pydantic-settings: fragments are LF-only (no CR characters)" {
  local frag
  for frag in "${TPL_DIR}/fragments/"*; do
    if grep -lU $'\r' "$frag" >/dev/null 2>&1; then
      fail "Fragment ${frag} contains CR characters; must be LF-only"
    fi
  done
}

# ── Fragments have proper dedup guard ────────────────────────────

@test "pydantic-settings: requirements/env fragments start with dropwsl:pydantic-settings guard" {
  local frag guard_pattern='# -- dropwsl:pydantic-settings --'
  for frag in "${TPL_DIR}/fragments/requirements.txt" \
              "${TPL_DIR}/fragments/env.example"; do
    local first_line
    first_line="$(grep -m1 '[^[:space:]]' "$frag")"
    if [[ "$first_line" != "$guard_pattern" ]]; then
      fail "Fragment ${frag} must start with '${guard_pattern}', got: '${first_line}'"
    fi
  done
}

# ── settings.py uses pydantic v2 (BaseSettings from pydantic_settings) ──

@test "pydantic-settings: settings.py imports BaseSettings from pydantic_settings" {
  grep -Fq 'from pydantic_settings import BaseSettings' \
    "${TPL_DIR}/templates/config/settings.py"
}

@test "pydantic-settings: settings.py uses model_config (pydantic v2), not class Config" {
  grep -Fq 'model_config = SettingsConfigDict' \
    "${TPL_DIR}/templates/config/settings.py"
  ! grep -E '^[[:space:]]*class Config' \
    "${TPL_DIR}/templates/config/settings.py"
}

@test "pydantic-settings: get_settings is decorated with @lru_cache" {
  grep -B0 -A1 '^def get_settings' "${TPL_DIR}/templates/config/settings.py" >/dev/null
  grep -q '@lru_cache' "${TPL_DIR}/templates/config/settings.py"
}

@test "pydantic-settings: cli.py declares all four subcommands" {
  local cli="${TPL_DIR}/templates/config/cli.py"
  grep -Fq 'add_parser("show"' "$cli"
  grep -Fq 'add_parser("validate"' "$cli"
  grep -Fq 'add_parser("dump-env"' "$cli"
  grep -Fq 'add_parser("schema"' "$cli"
}

# ── No real secrets shipped ──────────────────────────────────────

@test "pydantic-settings: no real bcrypt hash, API key or token literal in templates" {
  local f
  for f in "${TPL_DIR}/templates/config/"*.py \
           "${TPL_DIR}/fragments/"*; do
    if grep -Eq '\$2[aby]\$[0-9]{2}\$' "$f"; then
      fail "Real bcrypt hash detected in $f"
    fi
    if grep -Eq 'sk-[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}' "$f"; then
      fail "API key/AWS access key detected in $f"
    fi
  done
}

# ── Python templates compile ─────────────────────────────────────

@test "pydantic-settings: Python templates compile (syntax-only)" {
  command -v python3 >/dev/null || skip "python3 not available"
  local f
  for f in "${TPL_DIR}/templates/config/"*.py \
           "${TPL_DIR}/templates/tests/unit/test_config.py"; do
    if grep -Fq '{{' "$f"; then
      local rendered; rendered="$(mktemp)"
      sed -e 's|{{PKG_PREFIX}}||g' -e 's|{{PROJECT_NAME}}|my-project|g' \
        "$f" > "$rendered"
      python3 -m py_compile "$rendered" || fail "Syntax error in $f"
      rm -f "$rendered"
    else
      python3 -m py_compile "$f" || fail "Syntax error in $f"
    fi
  done
}
