#!/usr/bin/env bats
# tests/integration/combinations/test_layer_order_independence.bats
# Validates that apply_layers() produces the same result regardless of
# the user-specified --with order. The phase system must reorder layers
# so that structural layers (compose) run before infra layers (postgres, redis).

setup() {
  load '../../helpers/layer_test_helper'
  _common_setup
}

teardown() {
  _common_teardown
}

# Helper: create a fresh scaffold and run apply_layers with given order
_apply_with_order() {
  local layers_csv="$1"
  local project
  project="$(setup_project_scaffold "testapp")"
  apply_layers "$layers_csv" "$project" "testapp" "python" "${project}/.devcontainer" >&2
  echo "$project"
}

# ---- compose before postgres (lucky order) vs after (unlucky order) ----

@test "order: compose,postgres — postgres service injected" {
  local project
  project="$(_apply_with_order "src,fastapi,compose,postgres")"
  grep -Fq 'postgres:' "${project}/compose.yaml"
}

@test "order: postgres,compose — postgres service still injected" {
  local project
  project="$(_apply_with_order "src,fastapi,postgres,compose")"
  grep -Fq 'postgres:' "${project}/compose.yaml"
}

# ---- compose before redis vs after ----

@test "order: compose,redis — redis service injected" {
  local project
  project="$(_apply_with_order "src,fastapi,compose,redis")"
  grep -Fq 'redis:' "${project}/compose.yaml"
}

@test "order: redis,compose — redis service still injected" {
  local project
  project="$(_apply_with_order "src,fastapi,redis,compose")"
  grep -Fq 'redis:' "${project}/compose.yaml"
}

# ---- full stack: both orders ----

@test "order: compose,postgres,redis — both services injected" {
  local project
  project="$(_apply_with_order "src,fastapi,compose,postgres,redis")"
  grep -Fq 'postgres:' "${project}/compose.yaml"
  grep -Fq 'redis:' "${project}/compose.yaml"
}

@test "order: redis,postgres,compose — both services still injected" {
  local project
  project="$(_apply_with_order "src,fastapi,redis,postgres,compose")"
  grep -Fq 'postgres:' "${project}/compose.yaml"
  grep -Fq 'redis:' "${project}/compose.yaml"
}

# ---- compose alone (no infra consumers) ----

@test "order: compose alone creates skeleton" {
  local project
  project="$(_apply_with_order "src,fastapi,compose")"
  assert [ -f "${project}/compose.yaml" ]
  grep -Fq 'services:' "${project}/compose.yaml"
}

# ---- without compose: postgres/redis in standalone mode ----

@test "order: postgres without compose — no compose.yaml, RuntimeError in engine.py" {
  local project
  project="$(_apply_with_order "src,fastapi,postgres")"
  assert [ ! -f "${project}/compose.yaml" ]
  grep -Fq 'RuntimeError' "${project}/src/testapp/db/engine.py"
}

@test "order: redis without compose — no compose.yaml, RuntimeError in client.py" {
  local project
  project="$(_apply_with_order "src,fastapi,redis")"
  assert [ ! -f "${project}/compose.yaml" ]
  grep -Fq 'RuntimeError' "${project}/src/testapp/cache/client.py"
}

# ---- postgres+redis: redis injects into main.py AFTER postgres rewrites it ----

@test "order: postgres,redis — redis routes present in main.py" {
  local project
  project="$(_apply_with_order "src,fastapi,compose,postgres,redis")"
  local main_py="${project}/src/testapp/main.py"
  grep -Fq '/cache/{key}' "$main_py"
  grep -Fq 'redis_health' "$main_py"
}

@test "order: redis,postgres — redis routes still present (phase ordering)" {
  local project
  project="$(_apply_with_order "src,fastapi,compose,redis,postgres")"
  local main_py="${project}/src/testapp/main.py"
  grep -Fq '/cache/{key}' "$main_py"
  grep -Fq 'redis_health' "$main_py"
}

# ---- testcontainers creates in tests/integration/, redis fixtures in tests/fixtures/ ----

@test "order: postgres,redis,testcontainers — integration conftest + fixtures" {
  local project
  project="$(_apply_with_order "src,fastapi,postgres,redis,testcontainers")"
  grep -Fq 'testcontainers' "${project}/tests/integration/conftest.py"
  [ -f "${project}/tests/fixtures/db.py" ]
  [ -f "${project}/tests/fixtures/cache.py" ]
}

@test "order: testcontainers,redis,postgres — same result (phase ordering)" {
  local project
  project="$(_apply_with_order "src,fastapi,testcontainers,redis,postgres")"
  grep -Fq 'testcontainers' "${project}/tests/integration/conftest.py"
  [ -f "${project}/tests/fixtures/db.py" ]
  [ -f "${project}/tests/fixtures/cache.py" ]
}

# ---- azure-identity: order should not matter (infra phase) ----

@test "order: azure-identity before postgres — health includes both" {
  local project
  project="$(_apply_with_order "src,fastapi,compose,azure-identity,postgres")"
  local main_py="${project}/src/testapp/main.py"
  grep -Fq 'health_status["azure_identity"]' "$main_py"
  grep -Fq 'health_status["postgres"]' "$main_py"
}

@test "order: azure-identity after postgres — health still includes both" {
  local project
  project="$(_apply_with_order "src,fastapi,compose,postgres,azure-identity")"
  local main_py="${project}/src/testapp/main.py"
  grep -Fq 'health_status["azure_identity"]' "$main_py"
  grep -Fq 'health_status["postgres"]' "$main_py"
}

@test "order: azure-identity alone with fastapi — /api/identity route present" {
  local project
  project="$(_apply_with_order "src,fastapi,azure-identity")"
  local main_py="${project}/src/testapp/main.py"
  grep -Fq '/api/identity' "$main_py"
  grep -Fq 'credential_health' "$main_py"
}
