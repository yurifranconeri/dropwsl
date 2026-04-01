#!/usr/bin/env bats
# tests/integration/layer_shared/test_layer_gitleaks.bats

setup() {
  load '../../helpers/layer_test_helper'
  _common_setup
  PROJECT="$(setup_project_scaffold "testapp")"
  source_layer "${REPO_ROOT}/lib/layers/shared/gitleaks.sh"
}

teardown() {
  _common_teardown
}

@test "layer_gitleaks: .pre-commit-config.yaml created" {
  apply_layer_gitleaks "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -f "${PROJECT}/.pre-commit-config.yaml" ]
}

@test "layer_gitleaks: .gitleaks.toml created" {
  apply_layer_gitleaks "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -f "${PROJECT}/.gitleaks.toml" ]
}

@test "layer_gitleaks: post-create.sh contains pre-commit install" {
  apply_layer_gitleaks "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -q "pre-commit install" "${PROJECT}/.devcontainer/post-create.sh"
}

@test "layer_gitleaks: requirements-dev.txt contains pre-commit" {
  apply_layer_gitleaks "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "pre-commit" "${PROJECT}/requirements-dev.txt"
}

@test "layer_gitleaks: idempotent" {
  apply_layer_gitleaks "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local snap1="${TEST_TEMP}/snap1"
  cat "${PROJECT}/.pre-commit-config.yaml" > "$snap1"
  apply_layer_gitleaks "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  diff "$snap1" "${PROJECT}/.pre-commit-config.yaml"
}
