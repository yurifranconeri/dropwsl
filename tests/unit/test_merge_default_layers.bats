#!/usr/bin/env bats
# tests/unit/test_merge_default_layers.bats — Tests for _merge_default_layers()

setup() {
  load '../helpers/test_helper'
  _common_setup
  unset _NEW_SH_LOADED _LAYERS_SH_LOADED _SCAFFOLD_SH_LOADED _WORKSPACE_SH_LOADED
  source "${REPO_ROOT}/lib/project/layers.sh"
  source "${REPO_ROOT}/lib/project/scaffold.sh"
  source "${REPO_ROOT}/lib/project/workspace.sh"
  source "${REPO_ROOT}/lib/project/new.sh"
}

teardown() {
  _common_teardown
}

@test "merge_default_layers: merge with defaults" {
  DEFAULT_LAYERS=(src mypy)
  NO_DEFAULTS=false
  run _merge_default_layers "fastapi"
  assert_success
  assert_output --partial "fastapi"
  assert_output --partial "src"
  assert_output --partial "mypy"
}

@test "merge_default_layers: deduplication" {
  DEFAULT_LAYERS=(src)
  NO_DEFAULTS=false
  run _merge_default_layers "src,fastapi"
  assert_success
  # src should appear only once
  local count
  count=$(echo "$output" | tr ',' '\n' | grep -c '^src$')
  assert [ "$count" -eq 1 ]
}

@test "merge_default_layers: without defaults" {
  DEFAULT_LAYERS=()
  NO_DEFAULTS=false
  run _merge_default_layers "fastapi"
  assert_success
  assert_output "fastapi"
}

@test "merge_default_layers: NO_DEFAULTS=true bypass" {
  DEFAULT_LAYERS=(src mypy)
  NO_DEFAULTS=true
  run _merge_default_layers "fastapi"
  assert_success
  assert_output "fastapi"
  refute_output --partial "src"
  NO_DEFAULTS=false
}

@test "merge_default_layers: without user layers returns defaults" {
  DEFAULT_LAYERS=(src mypy)
  NO_DEFAULTS=false
  run _merge_default_layers ""
  assert_success
  assert_output --partial "src"
  assert_output --partial "mypy"
}

@test "merge_default_layers: uv default merges with user layers" {
  DEFAULT_LAYERS=(uv gitleaks trivy)
  NO_DEFAULTS=false
  run _merge_default_layers "fastapi,postgres"
  assert_success
  assert_output --partial "fastapi"
  assert_output --partial "postgres"
  assert_output --partial "uv"
  assert_output --partial "gitleaks"
  assert_output --partial "trivy"
}

@test "merge_default_layers: uv default deduplicates if user also passes uv" {
  DEFAULT_LAYERS=(uv gitleaks trivy)
  NO_DEFAULTS=false
  run _merge_default_layers "fastapi,uv"
  assert_success
  assert_output --partial "uv"
  local count
  count=$(echo "$output" | tr ',' '\n' | grep -c '^uv$')
  assert [ "$count" -eq 1 ]
}

@test "merge_default_layers: --no-defaults skips uv" {
  DEFAULT_LAYERS=(uv gitleaks trivy)
  NO_DEFAULTS=true
  run _merge_default_layers "fastapi"
  assert_success
  assert_output "fastapi"
  refute_output --partial "uv"
  refute_output --partial "gitleaks"
  NO_DEFAULTS=false
}
