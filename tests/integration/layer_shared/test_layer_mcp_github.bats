#!/usr/bin/env bats
# tests/integration/layer_shared/test_layer_mcp_github.bats

setup() {
  load '../../helpers/layer_test_helper'
  _common_setup
  PROJECT="$(setup_project_scaffold "testapp")"
  source_layer "${REPO_ROOT}/lib/layers/shared/mcp-github.sh"
}

teardown() {
  _common_teardown
}

@test "layer_mcp_github: .vscode/mcp.json created with server" {
  apply_layer_mcp_github "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -f "${PROJECT}/.vscode/mcp.json" ]
  grep -Fq "github" "${PROJECT}/.vscode/mcp.json"
}

@test "layer_mcp_github: inputs section com GITHUB_PERSONAL_ACCESS_TOKEN" {
  apply_layer_mcp_github "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -q "GITHUB_PERSONAL_ACCESS_TOKEN\|inputs" "${PROJECT}/.vscode/mcp.json"
}

@test "layer_mcp_github: idempotent" {
  apply_layer_mcp_github "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local snap1="${TEST_TEMP}/snap1"
  cat "${PROJECT}/.vscode/mcp.json" > "$snap1"
  apply_layer_mcp_github "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  diff "$snap1" "${PROJECT}/.vscode/mcp.json"
}

@test "layer_mcp_github: valid JSON" {
  apply_layer_mcp_github "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  if command -v python3 >/dev/null 2>&1; then
    python3 -m json.tool < "${PROJECT}/.vscode/mcp.json" >/dev/null 2>&1
  fi
}

# ---- Bug #96: inputs merge with pre-existing inputs array ----

@test "layer_mcp_github: inputs merge after mcp-fetch creates servers (no trailing comma)" {
  # mcp-fetch creates servers but no inputs array
  source_layer "${REPO_ROOT}/lib/layers/shared/mcp-fetch.sh"
  apply_layer_mcp_fetch "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"

  # mcp-github adds server + inputs (from scratch, since mcp-fetch has no inputs)
  apply_layer_mcp_github "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"

  # Both servers present
  grep -Fq '"fetch"' "${PROJECT}/.vscode/mcp.json"
  grep -Fq '"github"' "${PROJECT}/.vscode/mcp.json"
  grep -Fq '"github-pat"' "${PROJECT}/.vscode/mcp.json"

  # JSON must be valid (no trailing comma, no }, ])
  if command -v python3 >/dev/null 2>&1; then
    run python3 -m json.tool < "${PROJECT}/.vscode/mcp.json"
    assert_success
  fi
}

@test "layer_mcp_github: merge into pre-existing empty inputs array produces valid JSON" {
  # Plant mcp.json with an empty "inputs": [] — this is the bug #96 scenario
  mkdir -p "${PROJECT}/.vscode"
  cat > "${PROJECT}/.vscode/mcp.json" <<'JSON'
{
  "inputs": [],
  "servers": {
    "other-server": {
      "type": "stdio",
      "command": "other"
    }
  }
}
JSON

  apply_layer_mcp_github "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq '"github-pat"' "${PROJECT}/.vscode/mcp.json"
  grep -Fq '"github"' "${PROJECT}/.vscode/mcp.json"
  grep -Fq '"other-server"' "${PROJECT}/.vscode/mcp.json"

  if command -v python3 >/dev/null 2>&1; then
    run python3 -m json.tool < "${PROJECT}/.vscode/mcp.json"
    assert_success
  fi
}

@test "layer_mcp_github: merge into pre-existing non-empty inputs array produces valid JSON" {
  # Plant mcp.json with a populated inputs array — trailing comma acts as separator
  mkdir -p "${PROJECT}/.vscode"
  cat > "${PROJECT}/.vscode/mcp.json" <<'JSON'
{
  "inputs": [
    {
      "id": "other-token",
      "type": "promptString",
      "description": "Another token",
      "password": true
    }
  ],
  "servers": {
    "other-server": {
      "type": "stdio",
      "command": "other"
    }
  }
}
JSON

  apply_layer_mcp_github "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"

  grep -Fq '"github-pat"' "${PROJECT}/.vscode/mcp.json"
  grep -Fq '"other-token"' "${PROJECT}/.vscode/mcp.json"

  if command -v python3 >/dev/null 2>&1; then
    run python3 -m json.tool < "${PROJECT}/.vscode/mcp.json"
    assert_success
  fi
}

@test "layer_mcp_github: inputs standalone (without other MCP layers) is valid JSON" {
  apply_layer_mcp_github "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq '"github-pat"' "${PROJECT}/.vscode/mcp.json"
  grep -Fq '"inputs"' "${PROJECT}/.vscode/mcp.json"

  # Validate no }, ] pattern (trailing comma in array)
  run grep -F '},' "${PROJECT}/.vscode/mcp.json"
  # If }, exists, it should NOT be followed by ]
  if [[ "$status" -eq 0 ]]; then
    run grep -E '\},\s*\]' "${PROJECT}/.vscode/mcp.json"
    assert_failure  # No trailing comma before ]
  fi
}

@test "layer_mcp_github: double apply does not duplicate github-pat" {
  apply_layer_mcp_github "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_mcp_github "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"

  local count
  count="$(grep -c '"github-pat"' "${PROJECT}/.vscode/mcp.json")"
  assert_equal "$count" "1"
}
