#!/usr/bin/env bats
# tests/integration/test_inject_vscode_extension.bats

setup() {
  load '../helpers/test_helper'
  _common_setup
}

teardown() {
  _common_teardown
}

@test "inject_vscode_extension: adds new extension" {
  local dc="${TEST_TEMP}/devcontainer.json"
  cp "${REPO_ROOT}/tests/fixtures/devcontainer_base.json" "$dc"
  inject_vscode_extension "$dc" "ms-python.vscode-pylance"
  grep -Fq "ms-python.vscode-pylance" "$dc"
}

@test "inject_vscode_extension: extension already exists → skip" {
  local dc="${TEST_TEMP}/devcontainer.json"
  cp "${REPO_ROOT}/tests/fixtures/devcontainer_base.json" "$dc"
  local before
  before="$(cat "$dc")"
  inject_vscode_extension "$dc" "ms-python.python"
  local after
  after="$(cat "$dc")"
  assert [ "$before" = "$after" ]
}

@test "inject_vscode_extension: multiple sequential additions" {
  local dc="${TEST_TEMP}/devcontainer.json"
  cp "${REPO_ROOT}/tests/fixtures/devcontainer_base.json" "$dc"
  inject_vscode_extension "$dc" "ext.one"
  inject_vscode_extension "$dc" "ext.two"
  inject_vscode_extension "$dc" "ext.three"
  grep -Fq "ext.one" "$dc"
  grep -Fq "ext.two" "$dc"
  grep -Fq "ext.three" "$dc"
}

@test "inject_vscode_extension: valid JSON after addition" {
  local dc="${TEST_TEMP}/devcontainer.json"
  cp "${REPO_ROOT}/tests/fixtures/devcontainer_base.json" "$dc"
  inject_vscode_extension "$dc" "new.extension"
  if command -v python3 >/dev/null 2>&1; then
    python3 -m json.tool < "$dc" >/dev/null 2>&1
  fi
}

@test "inject_vscode_extension: nonexistent file → silent skip" {
  run inject_vscode_extension "${TEST_TEMP}/nonexistent.json" "ext.id"
  assert_success
}
