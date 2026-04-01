#!/usr/bin/env bats
# tests/unit/test_find_templates_dir.bats — Tests for find_templates_dir()

setup() {
  load '../helpers/test_helper'
  _common_setup
}

teardown() {
  _common_teardown
}

@test "find_templates_dir: SCRIPT_DIR with templates returns correct path" {
  SCRIPT_DIR="$REPO_ROOT"
  run find_templates_dir
  assert_success
  assert_output --partial "templates/devcontainer"
}

@test "find_templates_dir: SCRIPT_DIR without templates uses INSTALL_DIR" {
  local fake_install="${TEST_TEMP}/install"
  mkdir -p "${fake_install}/templates/devcontainer"
  SCRIPT_DIR="${TEST_TEMP}/nonexistent"
  INSTALL_DIR="$fake_install"
  run find_templates_dir
  assert_success
  assert_output --partial "${fake_install}/templates/devcontainer"
  SCRIPT_DIR="$REPO_ROOT"
}

@test "find_templates_dir: no valid path → die" {
  SCRIPT_DIR="${TEST_TEMP}/nodir1"
  INSTALL_DIR="${TEST_TEMP}/nodir2"
  run find_templates_dir
  assert_failure
  SCRIPT_DIR="$REPO_ROOT"
}
