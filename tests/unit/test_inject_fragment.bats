#!/usr/bin/env bats
# tests/unit/test_inject_fragment.bats — Tests for inject_fragment()

setup() {
  load '../helpers/test_helper'
  _common_setup
}

teardown() {
  _common_teardown
}

# ---------------------------------------------------------------------------
# Basic case: appends fragment to destination
# ---------------------------------------------------------------------------
@test "inject_fragment: appends content to destination" {
  local src="${TEST_TEMP}/frag.txt"
  local dest="${TEST_TEMP}/dest.txt"
  echo "existing content" > "$dest"
  echo "new dep>=1.0" > "$src"

  run inject_fragment "$src" "$dest"
  assert_success
  run cat "$dest"
  assert_line --index 0 "existing content"
  assert_line --index 1 "new dep>=1.0"
}

# ---------------------------------------------------------------------------
# Dedup: second call is skip
# ---------------------------------------------------------------------------
@test "inject_fragment: dedup — does not duplicate if guard already exists" {
  local src="${TEST_TEMP}/frag.txt"
  local dest="${TEST_TEMP}/dest.txt"
  echo "fastapi>=0.115" > "$src"
  printf "existing\nfastapi>=0.115\n" > "$dest"

  run inject_fragment "$src" "$dest"
  assert_success
  # Content unchanged — only 2 lines
  local count
  count="$(wc -l < "$dest")"
  assert [ "$count" -eq 2 ]
}

@test "inject_fragment: idempotent — calling 2x does not duplicate" {
  local src="${TEST_TEMP}/frag.txt"
  local dest="${TEST_TEMP}/dest.txt"
  echo "mypy>=1.11" > "$src"
  echo "# deps" > "$dest"

  inject_fragment "$src" "$dest"
  inject_fragment "$src" "$dest"
  local count
  count="$(grep -c 'mypy' "$dest")"
  assert [ "$count" -eq 1 ]
}

# ---------------------------------------------------------------------------
# Destination does not exist → silent skip (return 0)
# ---------------------------------------------------------------------------
@test "inject_fragment: nonexistent destination → skip without error" {
  local src="${TEST_TEMP}/frag.txt"
  echo "content" > "$src"

  run inject_fragment "$src" "${TEST_TEMP}/nope.txt"
  assert_success
  assert [ ! -f "${TEST_TEMP}/nope.txt" ]
}

# ---------------------------------------------------------------------------
# Nonexistent fragment → die
# ---------------------------------------------------------------------------
@test "inject_fragment: nonexistent fragment → die" {
  local dest="${TEST_TEMP}/dest.txt"
  echo "x" > "$dest"

  run inject_fragment "${TEST_TEMP}/nope.txt" "$dest"
  assert_failure
  assert_output --partial "fragment not found"
}

# ---------------------------------------------------------------------------
# Placeholder substitution
# ---------------------------------------------------------------------------
@test "inject_fragment: replaces placeholders before injecting" {
  local src="${TEST_TEMP}/frag.py"
  local dest="${TEST_TEMP}/conftest.py"
  echo "from {{PKG}}.main import app" > "$src"
  echo "# conftest" > "$dest"

  run inject_fragment "$src" "$dest" "PKG=acme"
  assert_success
  run grep 'from acme.main import app' "$dest"
  assert_success
}

@test "inject_fragment: multiple placeholders" {
  local src="${TEST_TEMP}/frag.txt"
  local dest="${TEST_TEMP}/dest.txt"
  echo "{{A}} and {{B}}" > "$src"
  echo "header" > "$dest"

  run inject_fragment "$src" "$dest" "A=hello" "B=world"
  assert_success
  run grep 'hello and world' "$dest"
  assert_success
}

# ---------------------------------------------------------------------------
# Caracteres especiais no valor
# ---------------------------------------------------------------------------
@test "inject_fragment: value with & is escaped" {
  local src="${TEST_TEMP}/frag.txt"
  local dest="${TEST_TEMP}/dest.txt"
  echo "url={{URL}}" > "$src"
  echo "# env" > "$dest"

  run inject_fragment "$src" "$dest" "URL=a&b"
  assert_success
  run grep 'url=a&b' "$dest"
  assert_success
}

# ---------------------------------------------------------------------------
# Fragment multi-linha
# ---------------------------------------------------------------------------
@test "inject_fragment: multi-line appends all lines" {
  local src="${TEST_TEMP}/frag.txt"
  local dest="${TEST_TEMP}/dest.txt"
  printf "line1\nline2\nline3\n" > "$src"
  echo "existing" > "$dest"

  run inject_fragment "$src" "$dest"
  assert_success
  local count
  count="$(wc -l < "$dest")"
  assert [ "$count" -eq 4 ]
}

# ---------------------------------------------------------------------------
# Guard with blank line at beginning of fragment
# ---------------------------------------------------------------------------
@test "inject_fragment: guard ignores blank lines at beginning" {
  local src="${TEST_TEMP}/frag.txt"
  local dest="${TEST_TEMP}/dest.txt"
  printf "\n\nactual_content\n" > "$src"
  echo "existing" > "$dest"

  run inject_fragment "$src" "$dest"
  assert_success
  run grep 'actual_content' "$dest"
  assert_success

  # Second call — guard should find 'actual_content' and skip
  local before after
  before="$(wc -l < "$dest")"
  inject_fragment "$src" "$dest"
  after="$(wc -l < "$dest")"
  assert [ "$before" -eq "$after" ]
}
