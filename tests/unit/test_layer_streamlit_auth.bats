#!/usr/bin/env bats
# tests/unit/test_layer_streamlit_auth.bats
# Pure structural / metadata checks for streamlit-auth layer
# (no scaffold required).

setup() {
  load '../helpers/test_helper'
  _common_setup
  LAYER_FILE="${REPO_ROOT}/lib/layers/python/streamlit-auth.sh"
  TPL_DIR="${REPO_ROOT}/templates/layers/python/streamlit-auth"
}

teardown() {
  _common_teardown
}

@test "streamlit-auth: layer file exists" {
  assert [ -f "$LAYER_FILE" ]
}

@test "streamlit-auth: has guard clause" {
  grep -q '_STREAMLIT_AUTH_SH_LOADED' "$LAYER_FILE"
}

@test "streamlit-auth: declares _LAYER_PHASE=tooling" {
  grep -q '^_LAYER_PHASE="tooling"' "$LAYER_FILE"
}

@test "streamlit-auth: declares _LAYER_REQUIRES=streamlit" {
  grep -q '^_LAYER_REQUIRES="streamlit"' "$LAYER_FILE"
}

@test "streamlit-auth: declares empty _LAYER_CONFLICTS" {
  grep -q '^_LAYER_CONFLICTS=""' "$LAYER_FILE"
}

@test "streamlit-auth: apply function defined" {
  grep -q '^apply_layer_streamlit_auth()' "$LAYER_FILE"
}

@test "streamlit-auth: no heredoc in layer file" {
  ! grep -q '<<' "$LAYER_FILE"
}

@test "streamlit-auth: layer does not reference other layers by name" {
  # Allowed: streamlit (declared as requires), bcrypt/PyYAML/streamlit-authenticator
  # in fragments (not in .sh).
  # Forbidden: detection of fastapi/postgres/redis/azure-*/uv etc inside .sh.
  ! grep -E 'has_(fastapi|postgres|redis|uv|mypy)|_HAS_API_FRAMEWORK' "$LAYER_FILE"
}

# ── Templates and fragments exist ────────────────────────────────

@test "streamlit-auth: all package templates exist" {
  assert [ -f "${TPL_DIR}/templates/users/__init__.py" ]
  assert [ -f "${TPL_DIR}/templates/users/__main__.py" ]
  assert [ -f "${TPL_DIR}/templates/users/gate.py" ]
  assert [ -f "${TPL_DIR}/templates/users/store.py" ]
  assert [ -f "${TPL_DIR}/templates/users/cli.py" ]
}

@test "streamlit-auth: users_data templates exist" {
  assert [ -f "${TPL_DIR}/templates/users_data/credentials.example.yaml" ]
  assert [ -f "${TPL_DIR}/templates/users_data/README.md" ]
}

@test "streamlit-auth: unit test template exists" {
  assert [ -f "${TPL_DIR}/templates/tests/unit/test_users.py" ]
}

@test "streamlit-auth: all required fragments exist" {
  for frag in requirements.txt env.example gitignore.txt dockerignore.txt readme-streamlit-auth.md; do
    assert [ -f "${TPL_DIR}/fragments/${frag}" ]
  done
}

# ── Fragments are LF-only (critical: dedup guard breaks on CRLF) ─

@test "streamlit-auth: fragments are LF-only (no CR characters)" {
  local frag
  for frag in "${TPL_DIR}/fragments/"*; do
    if grep -lU $'\r' "$frag" >/dev/null 2>&1; then
      fail "Fragment ${frag} contains CR characters; must be LF-only"
    fi
  done
}

# ── Fragments have proper dedup guard ────────────────────────────

@test "streamlit-auth: every fragment starts with dropwsl:streamlit-auth guard" {
  local frag guard_pattern='# -- dropwsl:streamlit-auth --'
  for frag in "${TPL_DIR}/fragments/requirements.txt" \
              "${TPL_DIR}/fragments/env.example" \
              "${TPL_DIR}/fragments/gitignore.txt" \
              "${TPL_DIR}/fragments/dockerignore.txt"; do
    local first_line
    first_line="$(grep -m1 '[^[:space:]]' "$frag")"
    if [[ "$first_line" != "$guard_pattern" ]]; then
      fail "Fragment ${frag} must start with '${guard_pattern}', got: '${first_line}'"
    fi
  done
}

# ── Example credentials file must not contain a real hash ────────

@test "streamlit-auth: credentials.example.yaml has no real bcrypt hash" {
  ! grep -Eq '\$2[aby]\$[0-9]{2}\$' "${TPL_DIR}/templates/users_data/credentials.example.yaml"
}

# ── Python templates compile ─────────────────────────────────────

@test "streamlit-auth: Python templates compile (syntax-only)" {
  command -v python3 >/dev/null || skip "python3 not available"
  local f
  for f in "${TPL_DIR}/templates/users/"*.py "${TPL_DIR}/templates/tests/unit/test_users.py"; do
    # __main__.py and cli.py contain {{PKG_PREFIX}} placeholder, render it first
    if grep -Fq '{{PKG_PREFIX}}' "$f"; then
      local rendered; rendered="$(mktemp)"
      sed 's|{{PKG_PREFIX}}||g' "$f" > "$rendered"
      python3 -m py_compile "$rendered" || fail "Syntax error in $f"
      rm -f "$rendered"
    else
      python3 -m py_compile "$f" || fail "Syntax error in $f"
    fi
  done
}
