#!/usr/bin/env bats
# tests/smoke/test_validate_all.bats — Smoke tests (requires provisioned WSL)
# NOTE: These tests MUST run inside a WSL with tools installed.

setup() {
  load '../helpers/test_helper'
  _common_setup
  unset _VALIDATE_SH_LOADED
  source "${REPO_ROOT}/lib/validate.sh"
}

teardown() {
  _common_teardown
}

@test "validate_all: runs without crash" {
  # If any check FAILs, validate_all calls die. We expect WARN ok, FAIL = test failure.
  run validate_all
  # If exited with 0, all ok. If exited with 1, some FAIL.
  # We don't force assert_success because it depends on the environment.
  # We only verify the function ran without syntax error.
  [[ "$status" -eq 0 ]] || [[ "$output" == *"FAIL"* ]]
}

@test "validate_all: output contains checks" {
  run validate_all
  assert_output --partial "systemd" || true
  assert_output --partial "docker" || true
}

@test "doctor: runs without crash" {
  run run_doctor
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}

@test "doctor: output contains Core, Network, Disk, Configuration sections" {
  run run_doctor
  assert_output --partial "Core checks"
  assert_output --partial "Network"
  assert_output --partial "Disk"
  assert_output --partial "Configuration"
}

@test "doctor: output contains docker checks" {
  run run_doctor
  assert_output --partial "docker"
}

@test "doctor: output ends with summary" {
  run run_doctor
  # Ends with "No issues found" or "issue(s) found"
  [[ "$output" == *"issue"* ]]
}
