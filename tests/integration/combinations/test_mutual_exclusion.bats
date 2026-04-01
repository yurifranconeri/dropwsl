#!/usr/bin/env bats
# tests/integration/combinations/test_mutual_exclusion.bats

setup() {
  load '../../helpers/layer_test_helper'
  _common_setup
}

teardown() {
  _common_teardown
}

@test "mutual_exclusion: fastapi + streamlit → die" {
  run validate_layers "fastapi,streamlit" "python"
  assert_failure
  assert_output --partial "mutually exclusive"
}

@test "mutual_exclusion: streamlit alone → ok" {
  run validate_layers "streamlit" "python"
  assert_success
}

@test "mutual_exclusion: fastapi alone → ok" {
  run validate_layers "fastapi" "python"
  assert_success
}

@test "mutual_exclusion: testcontainers without postgres → die" {
  run validate_layers "testcontainers" "python"
  assert_failure
  assert_output --partial "requires"
}

@test "mutual_exclusion: streamlit + fastapi in reversed order → die" {
  run validate_layers "streamlit,fastapi" "python"
  assert_failure
}
