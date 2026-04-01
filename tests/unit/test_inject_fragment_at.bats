#!/usr/bin/env bats
# tests/unit/test_inject_fragment_at.bats — Tests for inject_fragment_at()

setup() {
  load '../helpers/test_helper'
  _common_setup
}

teardown() {
  _common_teardown
}

# ---------------------------------------------------------------------------
# Basic case: inserts fragment after named marker
# ---------------------------------------------------------------------------
@test "inject_fragment_at: inserts content after marker line" {
  local src="${TEST_TEMP}/frag.txt"
  local dest="${TEST_TEMP}/dest.txt"
  echo "import foo" > "$src"
  printf 'header\n# -- dropwsl:imports --\nfooter\n' > "$dest"

  run inject_fragment_at "$src" "$dest" "imports"
  assert_success
  run cat "$dest"
  assert_line --index 0 "header"
  assert_line --index 1 "# -- dropwsl:imports --"
  assert_line --index 2 "import foo"
  assert_line --index 3 "footer"
}

# ---------------------------------------------------------------------------
# Fallback: appends when marker is missing
# ---------------------------------------------------------------------------
@test "inject_fragment_at: falls back to append without marker" {
  local src="${TEST_TEMP}/frag.txt"
  local dest="${TEST_TEMP}/dest.txt"
  echo "new line" > "$src"
  echo "existing" > "$dest"

  run inject_fragment_at "$src" "$dest" "nonexistent"
  assert_success
  run cat "$dest"
  assert_line --index 0 "existing"
  assert_line --index 1 "new line"
}

# ---------------------------------------------------------------------------
# Dedup: second call is skip (guard = first non-empty line)
# ---------------------------------------------------------------------------
@test "inject_fragment_at: dedup — does not duplicate if guard exists" {
  local src="${TEST_TEMP}/frag.txt"
  local dest="${TEST_TEMP}/dest.txt"
  echo "import foo" > "$src"
  printf 'header\n# -- dropwsl:imports --\nimport foo\nfooter\n' > "$dest"

  run inject_fragment_at "$src" "$dest" "imports"
  assert_success
  local count
  count="$(grep -c 'import foo' "$dest")"
  assert [ "$count" -eq 1 ]
}

@test "inject_fragment_at: idempotent — calling 2x does not duplicate" {
  local src="${TEST_TEMP}/frag.txt"
  local dest="${TEST_TEMP}/dest.txt"
  echo "import bar" > "$src"
  printf 'header\n# -- dropwsl:imports --\nfooter\n' > "$dest"

  inject_fragment_at "$src" "$dest" "imports"
  inject_fragment_at "$src" "$dest" "imports"
  local count
  count="$(grep -c 'import bar' "$dest")"
  assert [ "$count" -eq 1 ]
}

# ---------------------------------------------------------------------------
# Placeholder substitution
# ---------------------------------------------------------------------------
@test "inject_fragment_at: replaces {{PLACEHOLDERS}} before inserting" {
  local src="${TEST_TEMP}/frag.txt"
  local dest="${TEST_TEMP}/dest.txt"
  echo "from {{MODULE}} import app" > "$src"
  printf '# -- dropwsl:imports --\nrest\n' > "$dest"

  run inject_fragment_at "$src" "$dest" "imports" "MODULE=myapp.main"
  assert_success
  run grep 'from myapp.main import app' "$dest"
  assert_success
  run grep '{{MODULE}}' "$dest"
  assert_failure
}

# ---------------------------------------------------------------------------
# Fragment not found → die
# ---------------------------------------------------------------------------
@test "inject_fragment_at: dies if fragment file does not exist" {
  local dest="${TEST_TEMP}/dest.txt"
  echo "content" > "$dest"

  run inject_fragment_at "/nonexistent/frag.txt" "$dest" "imports"
  assert_failure
}

# ---------------------------------------------------------------------------
# Destination not found → silent skip (return 0)
# ---------------------------------------------------------------------------
@test "inject_fragment_at: returns 0 if dest does not exist" {
  local src="${TEST_TEMP}/frag.txt"
  echo "content" > "$src"

  run inject_fragment_at "$src" "/nonexistent/dest.txt" "imports"
  assert_success
}

# ---------------------------------------------------------------------------
# Multi-line fragment
# ---------------------------------------------------------------------------
@test "inject_fragment_at: inserts multi-line fragment after marker" {
  local src="${TEST_TEMP}/frag.txt"
  local dest="${TEST_TEMP}/dest.txt"
  printf 'import pytest\nfrom fastapi.testclient import TestClient\n' > "$src"
  printf 'header\n# -- dropwsl:imports --\n# -- dropwsl:fixtures --\nfooter\n' > "$dest"

  run inject_fragment_at "$src" "$dest" "imports"
  assert_success
  run cat "$dest"
  assert_line --index 0 "header"
  assert_line --index 1 "# -- dropwsl:imports --"
  assert_line --index 2 "import pytest"
  assert_line --index 3 "from fastapi.testclient import TestClient"
  assert_line --index 4 "# -- dropwsl:fixtures --"
  assert_line --index 5 "footer"
}

# ---------------------------------------------------------------------------
# Different sections can be targeted independently
# ---------------------------------------------------------------------------
@test "inject_fragment_at: targets correct section among multiple markers" {
  local src_imports="${TEST_TEMP}/imports.txt"
  local src_fixtures="${TEST_TEMP}/fixtures.txt"
  local dest="${TEST_TEMP}/dest.txt"
  echo "import os" > "$src_imports"
  echo "def my_fixture(): pass" > "$src_fixtures"
  printf 'header\n# -- dropwsl:imports --\n# -- dropwsl:fixtures --\nfooter\n' > "$dest"

  inject_fragment_at "$src_imports" "$dest" "imports"
  inject_fragment_at "$src_fixtures" "$dest" "fixtures"

  run cat "$dest"
  assert_line --index 0 "header"
  assert_line --index 1 "# -- dropwsl:imports --"
  assert_line --index 2 "import os"
  assert_line --index 3 "# -- dropwsl:fixtures --"
  assert_line --index 4 "def my_fixture(): pass"
  assert_line --index 5 "footer"
}

# ---------------------------------------------------------------------------
# Guard ignores blank lines at beginning of fragment
# ---------------------------------------------------------------------------
@test "inject_fragment_at: guard ignores leading blank lines" {
  local src="${TEST_TEMP}/frag.txt"
  local dest="${TEST_TEMP}/dest.txt"
  printf '\n\nactual_content\n' > "$src"
  printf '# -- dropwsl:imports --\nexisting\n' > "$dest"

  inject_fragment_at "$src" "$dest" "imports"

  run grep 'actual_content' "$dest"
  assert_success

  # Second call — guard finds 'actual_content' → skip
  local before after
  before="$(wc -l < "$dest")"
  inject_fragment_at "$src" "$dest" "imports"
  after="$(wc -l < "$dest")"
  assert [ "$before" -eq "$after" ]
}

# ---------------------------------------------------------------------------
# CRLF in fragment is stripped
# ---------------------------------------------------------------------------
@test "inject_fragment_at: strips CRLF from fragment" {
  local src="${TEST_TEMP}/frag.txt"
  local dest="${TEST_TEMP}/dest.txt"
  printf 'import foo\r\n' > "$src"
  printf '# -- dropwsl:imports --\nfooter\n' > "$dest"

  inject_fragment_at "$src" "$dest" "imports"
  # No \r should remain
  run grep $'\r' "$dest"
  assert_failure
  run grep 'import foo' "$dest"
  assert_success
}

# ---------------------------------------------------------------------------
# Placeholder with special sed chars (& | \)
# ---------------------------------------------------------------------------
@test "inject_fragment_at: handles special chars in placeholder values" {
  local src="${TEST_TEMP}/frag.txt"
  local dest="${TEST_TEMP}/dest.txt"
  echo "app={{APP}}" > "$src"
  printf '# -- dropwsl:imports --\nrest\n' > "$dest"

  run inject_fragment_at "$src" "$dest" "imports" "APP=foo&bar|baz"
  assert_success
  run grep 'app=foo&bar|baz' "$dest"
  assert_success
}
