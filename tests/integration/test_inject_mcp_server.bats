#!/usr/bin/env bats
# tests/integration/test_inject_mcp_server.bats — Tests for inject_mcp_server()

setup() {
  load '../helpers/test_helper'
  _common_setup
}

teardown() {
  _common_teardown
}

@test "inject_mcp_server: creates mcp.json from scratch" {
  local project="${TEST_TEMP}/proj"
  mkdir -p "$project"
  local block='      "type": "stdio",
      "command": "npx",
      "args": ["@test/server"]'

  inject_mcp_server "$project" "test-server" "$block"
  assert [ -f "${project}/.vscode/mcp.json" ]
  grep -Fq '"test-server"' "${project}/.vscode/mcp.json"
  grep -Fq '"stdio"' "${project}/.vscode/mcp.json"
}

@test "inject_mcp_server: adds server to existing mcp.json" {
  local project="${TEST_TEMP}/proj"
  mkdir -p "${project}/.vscode"
  cp "${REPO_ROOT}/tests/fixtures/mcp_with_servers.json" "${project}/.vscode/mcp.json"

  local block='      "type": "stdio",
      "command": "test2"'

  inject_mcp_server "$project" "new-server" "$block"
  grep -Fq '"existing-server"' "${project}/.vscode/mcp.json"
  grep -Fq '"new-server"' "${project}/.vscode/mcp.json"
}

@test "inject_mcp_server: existing server → skip (idempotent)" {
  local project="${TEST_TEMP}/proj"
  mkdir -p "${project}/.vscode"
  cp "${REPO_ROOT}/tests/fixtures/mcp_with_servers.json" "${project}/.vscode/mcp.json"
  local before
  before="$(cat "${project}/.vscode/mcp.json")"

  inject_mcp_server "$project" "existing-server" '"type": "noop"'
  local after
  after="$(cat "${project}/.vscode/mcp.json")"
  assert [ "$before" = "$after" ]
}

@test "inject_mcp_server: JSON malformado → return 1" {
  local project="${TEST_TEMP}/proj"
  mkdir -p "${project}/.vscode"
  echo "not json at all" > "${project}/.vscode/mcp.json"

  run inject_mcp_server "$project" "server" '"type": "test"'
  assert_failure
}

@test "inject_mcp_server: valid JSON after creation" {
  local project="${TEST_TEMP}/proj"
  mkdir -p "$project"
  local block='      "type": "stdio",
      "command": "test"'

  inject_mcp_server "$project" "server1" "$block"

  if command -v python3 >/dev/null 2>&1; then
    python3 -m json.tool < "${project}/.vscode/mcp.json" >/dev/null 2>&1
  fi
}

@test "inject_mcp_server: valid JSON after multiple servers" {
  local project="${TEST_TEMP}/proj"
  mkdir -p "$project"
  local block='      "type": "stdio",
      "command": "test"'

  inject_mcp_server "$project" "server1" "$block"
  inject_mcp_server "$project" "server2" "$block"
  inject_mcp_server "$project" "server3" "$block"

  # All present
  grep -Fq '"server1"' "${project}/.vscode/mcp.json"
  grep -Fq '"server2"' "${project}/.vscode/mcp.json"
  grep -Fq '"server3"' "${project}/.vscode/mcp.json"

  if command -v python3 >/dev/null 2>&1; then
    python3 -m json.tool < "${project}/.vscode/mcp.json" >/dev/null 2>&1
  fi
}

# ---- Bug #89/#111: trailing newlines and head -n -2 edge case ----

@test "inject_mcp_server: trailing newlines in mcp.json don't corrupt JSON" {
  local project="${TEST_TEMP}/proj"
  mkdir -p "${project}/.vscode"
  # Create valid mcp.json with 2 trailing blank lines
  printf '{\n  "servers": {\n    "existing": {\n      "type": "stdio"\n    }\n  }\n}\n\n\n' > "${project}/.vscode/mcp.json"

  local block='      "type": "stdio",
      "command": "test"'

  inject_mcp_server "$project" "new-server" "$block"
  grep -Fq '"existing"' "${project}/.vscode/mcp.json"
  grep -Fq '"new-server"' "${project}/.vscode/mcp.json"

  if command -v python3 >/dev/null 2>&1; then
    run python3 -m json.tool < "${project}/.vscode/mcp.json"
    assert_success
  fi
}

@test "inject_mcp_server: exactly one root closing brace after multiple injections" {
  local project="${TEST_TEMP}/proj"
  mkdir -p "$project"
  local block='      "type": "stdio",
      "command": "test"'

  inject_mcp_server "$project" "s1" "$block"
  inject_mcp_server "$project" "s2" "$block"
  inject_mcp_server "$project" "s3" "$block"

  # Count root-level closing braces (lines that are exactly "}")
  local root_braces
  root_braces="$(grep -c '^}$' "${project}/.vscode/mcp.json")"
  assert_equal "$root_braces" "1"
}
