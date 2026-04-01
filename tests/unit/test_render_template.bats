#!/usr/bin/env bats
# tests/unit/test_render_template.bats — Tests for render_template()

setup() {
  load '../helpers/test_helper'
  _common_setup
}

teardown() {
  _common_teardown
}

# ---------------------------------------------------------------------------
# Basic case: copies template without placeholders
# ---------------------------------------------------------------------------
@test "render_template: copies file without placeholders" {
  local src="${TEST_TEMP}/tpl.txt"
  local dest="${TEST_TEMP}/out/result.txt"
  echo "Hello World" > "$src"

  run render_template "$src" "$dest"
  assert_success
  assert [ -f "$dest" ]
  run cat "$dest"
  assert_output "Hello World"
}

# ---------------------------------------------------------------------------
# Placeholder substitution
# ---------------------------------------------------------------------------
@test "render_template: replaces simple placeholder" {
  local src="${TEST_TEMP}/tpl.py"
  local dest="${TEST_TEMP}/out.py"
  cat > "$src" <<'EOF'
app = FastAPI(title="{{PROJECT_NAME}}")
EOF

  run render_template "$src" "$dest" "PROJECT_NAME=meu-app"
  assert_success
  run cat "$dest"
  assert_output 'app = FastAPI(title="meu-app")'
}

@test "render_template: replaces multiple placeholders" {
  local src="${TEST_TEMP}/tpl.txt"
  local dest="${TEST_TEMP}/out.txt"
  cat > "$src" <<'EOF'
name={{NAME}}, version={{VERSION}}, name={{NAME}}
EOF

  run render_template "$src" "$dest" "NAME=foo" "VERSION=1.0"
  assert_success
  run cat "$dest"
  assert_output "name=foo, version=1.0, name=foo"
}

@test "render_template: unprovided placeholder remains intact" {
  local src="${TEST_TEMP}/tpl.txt"
  local dest="${TEST_TEMP}/out.txt"
  echo "val={{MISSING}}" > "$src"

  run render_template "$src" "$dest"
  assert_success
  run cat "$dest"
  assert_output "val={{MISSING}}"
}

# ---------------------------------------------------------------------------
# Escape de caracteres especiais (sed-unsafe)
# ---------------------------------------------------------------------------
@test "render_template: value with & is escaped correctly" {
  local src="${TEST_TEMP}/tpl.txt"
  local dest="${TEST_TEMP}/out.txt"
  echo "url={{URL}}" > "$src"

  run render_template "$src" "$dest" "URL=foo&bar"
  assert_success
  run cat "$dest"
  assert_output "url=foo&bar"
}

@test "render_template: value with | is escaped correctly" {
  local src="${TEST_TEMP}/tpl.txt"
  local dest="${TEST_TEMP}/out.txt"
  echo "cmd={{CMD}}" > "$src"

  run render_template "$src" "$dest" "CMD=a|b|c"
  assert_success
  run cat "$dest"
  assert_output "cmd=a|b|c"
}

@test "render_template: value with backslash is escaped correctly" {
  local src="${TEST_TEMP}/tpl.txt"
  local dest="${TEST_TEMP}/out.txt"
  echo "path={{PATH_VAL}}" > "$src"

  run render_template "$src" "$dest" 'PATH_VAL=C:\Users\test'
  assert_success
  run cat "$dest"
  assert_output 'path=C:\Users\test'
}

# ---------------------------------------------------------------------------
# Intermediate directory creation
# ---------------------------------------------------------------------------
@test "render_template: creates intermediate directories" {
  local src="${TEST_TEMP}/tpl.txt"
  local dest="${TEST_TEMP}/a/b/c/out.txt"
  echo "deep" > "$src"

  run render_template "$src" "$dest"
  assert_success
  assert [ -f "$dest" ]
  run cat "$dest"
  assert_output "deep"
}

# ---------------------------------------------------------------------------
# Errors
# ---------------------------------------------------------------------------
@test "render_template: nonexistent template → die" {
  run render_template "${TEST_TEMP}/nope.txt" "${TEST_TEMP}/out.txt"
  assert_failure
  assert_output --partial "template not found"
}

# ---------------------------------------------------------------------------
# Multi-line template with multiple placeholders
# ---------------------------------------------------------------------------
@test "render_template: multi-line file with substitutions" {
  local src="${TEST_TEMP}/main.py"
  local dest="${TEST_TEMP}/out.py"
  cat > "$src" <<'EOF'
"""{{PROJECT_NAME}} — API."""

from fastapi import FastAPI

app = FastAPI(title="{{PROJECT_NAME}}", version="{{VERSION}}")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("{{IMPORT_APP}}", host="0.0.0.0", port=8000)
EOF

  run render_template "$src" "$dest" \
    "PROJECT_NAME=acme" \
    "VERSION=2.0.0" \
    "IMPORT_APP=acme.main:app"
  assert_success
  run grep -c 'acme' "$dest"
  assert_output "3"
  run grep 'version="2.0.0"' "$dest"
  assert_success
  run grep 'acme.main:app' "$dest"
  assert_success
}
