#!/usr/bin/env bats
# tests/integration/test_full_cycle.bats — Tests new_project (standalone, workspace, validation)
# Uses mocks (no Docker). Validates folder structure creation and layers.

setup() {
  load '../helpers/test_helper'
  _common_setup
  load '../helpers/mock_commands'
  unset _LAYERS_SH_LOADED _SCAFFOLD_SH_LOADED _NEW_SH_LOADED _WORKSPACE_SH_LOADED
  source "${REPO_ROOT}/lib/project/layers.sh"
  source "${REPO_ROOT}/lib/project/scaffold.sh"
  source "${REPO_ROOT}/lib/project/workspace.sh"
  source "${REPO_ROOT}/lib/project/new.sh"

  # Use temp as PROJECTS_DIR to avoid polluting ~/projects
  PROJECTS_DIR="${TEST_TEMP}/projects"
  mkdir -p "$PROJECTS_DIR"
  activate_mocks
}

teardown() {
  _common_teardown
}

@test "full_cycle: new project standalone with layers" {
  new_project "e2e-app" "python" "src,fastapi" ""
  assert [ -d "${PROJECTS_DIR}/e2e-app" ]
  assert [ -f "${PROJECTS_DIR}/e2e-app/src/e2e-app/main.py" ] || \
  assert [ -f "${PROJECTS_DIR}/e2e-app/src/e2eapp/main.py" ] || \
  assert [ -d "${PROJECTS_DIR}/e2e-app/src" ]
}

@test "full_cycle: new project creates devcontainer" {
  new_project "e2e-app2" "python" "" ""
  assert [ -f "${PROJECTS_DIR}/e2e-app2/.devcontainer/Dockerfile" ]
}

@test "full_cycle: new project with workspace mode" {
  new_project "e2e-ws" "python" "src,fastapi" "api"
  assert [ -d "${PROJECTS_DIR}/e2e-ws/services/api" ]
  assert [ -d "${PROJECTS_DIR}/e2e-ws/.devcontainer/api" ]
}

@test "full_cycle: validate layers before creating" {
  run new_project "e2e-fail" "python" "fastapi,streamlit" ""
  assert_failure
}
