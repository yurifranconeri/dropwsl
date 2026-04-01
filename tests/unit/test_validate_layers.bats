#!/usr/bin/env bats
# tests/unit/test_validate_layers.bats — Tests for validate_layers()

setup() {
  load '../helpers/test_helper'
  _common_setup
  unset _LAYERS_SH_LOADED
  source "${REPO_ROOT}/lib/project/layers.sh"
}

teardown() {
  _common_teardown
}

@test "validate_layers: all valid" {
  run validate_layers "src,fastapi,mypy" "python"
  assert_success
}

@test "validate_layers: nonexistent layer → die" {
  run validate_layers "src,foobar_not_real" "python"
  assert_failure
}

@test "validate_layers: mutual exclusion fastapi and streamlit" {
  run validate_layers "fastapi,streamlit" "python"
  assert_failure
  assert_output --partial "mutually exclusive"
}

@test "validate_layers: testcontainers without postgres → die" {
  run validate_layers "testcontainers" "python"
  assert_failure
  assert_output --partial "requires 'postgres'"
}

@test "validate_layers: testcontainers with postgres → ok" {
  run validate_layers "postgres,testcontainers" "python"
  assert_success
}

@test "validate_layers: empty string → ok" {
  run validate_layers "" "python"
  assert_success
}

@test "validate_layers: layers with spaces" {
  run validate_layers "src, fastapi, mypy" "python"
  assert_success
}
