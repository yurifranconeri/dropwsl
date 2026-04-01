#!/usr/bin/env bats
# tests/integration/test_inject_compose_service.bats

setup() {
  load '../helpers/test_helper'
  _common_setup
}

teardown() {
  _common_teardown
}

@test "inject_compose_service: creates compose.yaml with service" {
  local project="${TEST_TEMP}/proj"
  mkdir -p "$project"
  local block='    build: .
    ports:
      - "8000:8000"'

  inject_compose_service "$project" "api" "$block"
  assert [ -f "${project}/compose.yaml" ]
  grep -Fq "api:" "${project}/compose.yaml"
  grep -Fq "8000:8000" "${project}/compose.yaml"
}

@test "inject_compose_service: expands services: {} to mapping" {
  local project="${TEST_TEMP}/proj"
  mkdir -p "$project"
  cp "${REPO_ROOT}/tests/fixtures/compose_empty.yaml" "${project}/compose.yaml"

  local block='    build: .
    ports:
      - "8000:8000"'

  inject_compose_service "$project" "api" "$block"
  ! grep -Fq 'services: {}' "${project}/compose.yaml"
  grep -Fq "api:" "${project}/compose.yaml"
}

@test "inject_compose_service: adds second service" {
  local project="${TEST_TEMP}/proj"
  mkdir -p "$project"
  cp "${REPO_ROOT}/tests/fixtures/compose_with_service.yaml" "${project}/compose.yaml"

  local block='    image: postgres:16
    ports:
      - "5432:5432"'

  inject_compose_service "$project" "db" "$block"
  grep -Fq "api:" "${project}/compose.yaml"
  grep -Fq "db:" "${project}/compose.yaml"
}

@test "inject_compose_service: existing service → skip (idempotent)" {
  local project="${TEST_TEMP}/proj"
  mkdir -p "$project"
  cp "${REPO_ROOT}/tests/fixtures/compose_with_service.yaml" "${project}/compose.yaml"
  local before
  before="$(cat "${project}/compose.yaml")"

  inject_compose_service "$project" "api" "nope"
  local after
  after="$(cat "${project}/compose.yaml")"
  assert [ "$before" = "$after" ]
}

@test "inject_compose_service: with volume" {
  local project="${TEST_TEMP}/proj"
  mkdir -p "$project"

  local block='    image: postgres:16
    volumes:
      - pg_data:/var/lib/postgresql/data'
  local vol='  pg_data:'

  inject_compose_service "$project" "db" "$block" "$vol"
  grep -Fq "db:" "${project}/compose.yaml"
  grep -Fq "pg_data:" "${project}/compose.yaml"
  grep -Fq "volumes:" "${project}/compose.yaml"
}

@test "inject_compose_service: multiple sequential services" {
  local project="${TEST_TEMP}/proj"
  mkdir -p "$project"

  inject_compose_service "$project" "api" '    build: .'
  inject_compose_service "$project" "db" '    image: postgres:16'
  inject_compose_service "$project" "redis" '    image: redis:7-alpine'

  grep -Fq "api:" "${project}/compose.yaml"
  grep -Fq "db:" "${project}/compose.yaml"
  grep -Fq "redis:" "${project}/compose.yaml"
}
