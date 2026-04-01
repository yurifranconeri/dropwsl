#!/usr/bin/env bats
# tests/install/test_validate.bats -- Runs validate_all + doctor after install
#
# REQUIREMENTS:
#   - Runs inside WSL with dropwsl fully provisioned
#   - install.cmd must have completed successfully
#
# These tests confirm the official validation commands pass.
# If validate_all fails, the installation has a regression.

setup() {
  load '../helpers/test_helper'
  _common_setup
  unset _VALIDATE_SH_LOADED
  source "${REPO_ROOT}/lib/validate.sh"
}

teardown() {
  _common_teardown
}

# ---- validate_all ----

@test "validate: runs without crash" {
  run validate_all
  # exit 0 = all OK, exit 1 = at least one FAIL
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

@test "validate: all FAIL-level checks pass" {
  run validate_all
  assert_success
}

@test "validate: output contains systemd check" {
  run validate_all
  assert_output --partial "systemd"
}

@test "validate: output contains docker check" {
  run validate_all
  assert_output --partial "docker"
}

@test "validate: output contains docker compose check" {
  run validate_all
  assert_output --partial "compose"
}

# ---- doctor ----

@test "doctor: runs without crash" {
  run run_doctor
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

@test "doctor: output contains Core checks" {
  run run_doctor
  assert_output --partial "Core"
}

@test "doctor: ends with summary" {
  run run_doctor
  # Ends with a count of problems or "no problems"
  [[ "$output" == *"problem"* ]] || [[ "$output" == *"problema"* ]]
}
