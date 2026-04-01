#!/usr/bin/env bats
# tests/unit/test_resolve_layer.bats — Tests for resolve_layer_file()

setup() {
  load '../helpers/test_helper'
  _common_setup
  unset _LAYERS_SH_LOADED
  source "${REPO_ROOT}/lib/project/layers.sh"
}

teardown() {
  _common_teardown
}

@test "resolve_layer_file: Python layer exists" {
  run resolve_layer_file "fastapi" "python"
  assert_success
  assert_output --partial "layers/python/fastapi.sh"
}

@test "resolve_layer_file: shared layer exists" {
  run resolve_layer_file "compose" "python"
  assert_success
  assert_output --partial "layers/shared/compose.sh"
}

@test "resolve_layer_file: Python has priority over shared" {
  run resolve_layer_file "src" "python"
  assert_success
  assert_output --partial "layers/python/src.sh"
}

@test "resolve_layer_file: nonexistent layer → die" {
  run resolve_layer_file "foobar_nonexistent" "python"
  assert_failure
}

@test "resolve_layer_file: shared layer without lang-specific" {
  run resolve_layer_file "trivy" "python"
  assert_success
  assert_output --partial "layers/shared/trivy.sh"
}
