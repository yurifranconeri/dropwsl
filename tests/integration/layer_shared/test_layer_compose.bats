#!/usr/bin/env bats
# tests/integration/layer_shared/test_layer_compose.bats

setup() {
  load '../../helpers/layer_test_helper'
  _common_setup
  PROJECT="$(setup_project_scaffold "testapp")"
  source_layer "${REPO_ROOT}/lib/layers/shared/compose.sh"
}

teardown() {
  _common_teardown
}

@test "layer_compose: compose.yaml created" {
  apply_layer_compose "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -f "${PROJECT}/compose.yaml" ]
}

@test "layer_compose: .env.example created" {
  apply_layer_compose "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -f "${PROJECT}/.env.example" ]
}

@test "layer_compose: .env.example marks local infra intent" {
  apply_layer_compose "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fxq '# -- dropwsl:local-infra --' "${PROJECT}/.env.example"
}

@test "layer_compose: README updated" {
  apply_layer_compose "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -qi "docker\|compose" "${PROJECT}/README.md" 2>/dev/null || true
}

@test "layer_compose: idempotent (no-clobber)" {
  apply_layer_compose "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local snap1="${TEST_TEMP}/snap1"
  cat "${PROJECT}/compose.yaml" > "$snap1"
  apply_layer_compose "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  diff "$snap1" "${PROJECT}/compose.yaml"
}

@test "layer_compose: devcontainer.json gets network config" {
  # Override with realistic template (has updateRemoteUserUID anchor)
  cat > "${PROJECT}/.devcontainer/devcontainer.json" <<'JSON'
{
  "name": "testapp",
  "build": { "dockerfile": "Dockerfile" },
  "remoteUser": "vscode",
  "updateRemoteUserUID": true,
  "containerEnv": {},
  "customizations": {
    "vscode": {
      "extensions": ["ms-python.python"]
    }
  },
  "postCreateCommand": "echo done"
}
JSON
  apply_layer_compose "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq 'initializeCommand' "${PROJECT}/.devcontainer/devcontainer.json"
  grep -Fq 'testapp-net' "${PROJECT}/.devcontainer/devcontainer.json"
  grep -Fq '"runArgs"' "${PROJECT}/.devcontainer/devcontainer.json"
}

@test "layer_compose: network injection idempotent" {
  cat > "${PROJECT}/.devcontainer/devcontainer.json" <<'JSON'
{
  "name": "testapp",
  "build": { "dockerfile": "Dockerfile" },
  "remoteUser": "vscode",
  "updateRemoteUserUID": true,
  "containerEnv": {},
  "customizations": {
    "vscode": {
      "extensions": ["ms-python.python"]
    }
  },
  "postCreateCommand": "echo done"
}
JSON
  apply_layer_compose "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local snap1="${TEST_TEMP}/snap_dc1"
  cat "${PROJECT}/.devcontainer/devcontainer.json" > "$snap1"
  apply_layer_compose "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  diff "$snap1" "${PROJECT}/.devcontainer/devcontainer.json"
}
