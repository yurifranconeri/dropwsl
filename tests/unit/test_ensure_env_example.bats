#!/usr/bin/env bats
# tests/unit/test_ensure_env_example.bats — Tests for ensure_env_example()

setup() {
  load '../helpers/test_helper'
  _common_setup
}

teardown() {
  _common_teardown
}

@test "ensure_env_example: creates .env.example with header" {
  local proj="${TEST_TEMP}/proj"
  mkdir -p "$proj"

  ensure_env_example "$proj"

  assert [ -f "${proj}/.env.example" ]
  grep -Fq "copy to .env" "${proj}/.env.example"
  grep -Fq ".gitignore" "${proj}/.env.example"
}

@test "ensure_env_example: no-clobber if already exists" {
  local proj="${TEST_TEMP}/proj"
  mkdir -p "$proj"
  echo "# custom header" > "${proj}/.env.example"

  ensure_env_example "$proj"

  # Original content preserved
  grep -Fq "# custom header" "${proj}/.env.example"
  # Default header was NOT added
  ! grep -Fq "copy to .env" "${proj}/.env.example"
}

@test "ensure_env_example: idempotent" {
  local proj="${TEST_TEMP}/proj"
  mkdir -p "$proj"

  ensure_env_example "$proj"
  local hash1; hash1="$(md5sum "${proj}/.env.example" | cut -d' ' -f1)"

  ensure_env_example "$proj"
  local hash2; hash2="$(md5sum "${proj}/.env.example" | cut -d' ' -f1)"

  [ "$hash1" = "$hash2" ]
}
