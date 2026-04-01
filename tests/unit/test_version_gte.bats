#!/usr/bin/env bats
# tests/unit/test_version_gte.bats — Tests for version_gte()

setup() {
  load '../helpers/test_helper'
  _common_setup
}

teardown() {
  _common_teardown
}

@test "version_gte: equal versions" {
  run version_gte "1.2.3" "1.2.3"
  assert_success
}

@test "version_gte: higher major" {
  run version_gte "2.0.0" "1.9.9"
  assert_success
}

@test "version_gte: lower major" {
  run version_gte "1.0.0" "2.0.0"
  assert_failure
}

@test "version_gte: higher minor" {
  run version_gte "1.3.0" "1.2.9"
  assert_success
}

@test "version_gte: lower minor" {
  run version_gte "1.2.0" "1.3.0"
  assert_failure
}

@test "version_gte: higher patch" {
  run version_gte "1.2.4" "1.2.3"
  assert_success
}

@test "version_gte: lower patch" {
  run version_gte "1.2.2" "1.2.3"
  assert_failure
}

@test "version_gte: v prefix" {
  run version_gte "v1.2.3" "v1.2.3"
  assert_success
}

@test "version_gte: mixed v prefix" {
  run version_gte "v2.0.0" "1.0.0"
  assert_success
}

@test "version_gte: two segments equal" {
  run version_gte "22.04" "22.04"
  assert_success
}

@test "version_gte: two segments higher" {
  run version_gte "24.04" "22.04"
  assert_success
}

@test "version_gte: two segments lower" {
  run version_gte "20.04" "22.04"
  assert_failure
}

@test "version_gte: four segments" {
  run version_gte "1.2.3.4" "1.2.3.3"
  assert_success
}
