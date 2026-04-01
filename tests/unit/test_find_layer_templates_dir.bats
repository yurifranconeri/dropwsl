#!/usr/bin/env bats
# tests/unit/test_find_layer_templates_dir.bats — Tests for find_layer_templates_dir()

setup() {
  load '../helpers/test_helper'
  _common_setup
}

teardown() {
  _common_teardown
}

# ---------------------------------------------------------------------------
# Valid SCRIPT_DIR
# ---------------------------------------------------------------------------
@test "find_layer_templates_dir: SCRIPT_DIR with layer returns correct path" {
  local fake="${TEST_TEMP}/repo"
  mkdir -p "${fake}/templates/layers/python/fastapi"
  SCRIPT_DIR="$fake"

  run find_layer_templates_dir "python" "fastapi"
  assert_success
  assert_output "${fake}/templates/layers/python/fastapi"
  SCRIPT_DIR="$REPO_ROOT"
}

# ---------------------------------------------------------------------------
# Fallback to INSTALL_DIR
# ---------------------------------------------------------------------------
@test "find_layer_templates_dir: fallback to INSTALL_DIR" {
  local fake_install="${TEST_TEMP}/install"
  mkdir -p "${fake_install}/templates/layers/shared/compose"
  SCRIPT_DIR="${TEST_TEMP}/nonexistent"
  INSTALL_DIR="$fake_install"

  run find_layer_templates_dir "shared" "compose"
  assert_success
  assert_output "${fake_install}/templates/layers/shared/compose"
  SCRIPT_DIR="$REPO_ROOT"
}

# ---------------------------------------------------------------------------
# No valid path → die
# ---------------------------------------------------------------------------
@test "find_layer_templates_dir: no valid path → die" {
  SCRIPT_DIR="${TEST_TEMP}/nodir1"
  INSTALL_DIR="${TEST_TEMP}/nodir2"

  run find_layer_templates_dir "python" "nonexistent"
  assert_failure
  assert_output --partial "Templates for layer 'nonexistent' not found"
  SCRIPT_DIR="$REPO_ROOT"
}

# ---------------------------------------------------------------------------
# Scopes diferentes
# ---------------------------------------------------------------------------
@test "find_layer_templates_dir: shared scope works" {
  local fake="${TEST_TEMP}/repo"
  mkdir -p "${fake}/templates/layers/shared/gitleaks"
  SCRIPT_DIR="$fake"

  run find_layer_templates_dir "shared" "gitleaks"
  assert_success
  assert_output "${fake}/templates/layers/shared/gitleaks"
  SCRIPT_DIR="$REPO_ROOT"
}

@test "find_layer_templates_dir: python scope works" {
  local fake="${TEST_TEMP}/repo"
  mkdir -p "${fake}/templates/layers/python/postgres"
  SCRIPT_DIR="$fake"

  run find_layer_templates_dir "python" "postgres"
  assert_success
  assert_output "${fake}/templates/layers/python/postgres"
  SCRIPT_DIR="$REPO_ROOT"
}
