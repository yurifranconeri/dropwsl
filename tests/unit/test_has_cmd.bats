#!/usr/bin/env bats
# tests/unit/test_has_cmd.bats — Tests for has_cmd()

setup() {
  load '../helpers/test_helper'
  _common_setup
}

teardown() {
  _common_teardown
}

@test "has_cmd: existing command (bash)" {
  run has_cmd bash
  assert_success
}

@test "has_cmd: nonexistent command" {
  run has_cmd xyzzy_cmd_not_real_99
  assert_failure
}

@test "has_cmd: builtin echo" {
  run has_cmd echo
  assert_success
}

@test "has_cmd: empty string returns false" {
  run has_cmd ""
  assert_failure
}
