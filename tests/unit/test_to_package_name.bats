#!/usr/bin/env bats
# tests/unit/test_to_package_name.bats — Tests for _to_package_name()

setup() {
  load '../helpers/test_helper'
  _common_setup
}

teardown() {
  _common_teardown
}

@test "_to_package_name: hyphens become underscores" {
  run _to_package_name "my-project"
  assert_success
  assert_output "my_project"
}

@test "_to_package_name: dots become underscores" {
  run _to_package_name "my.project"
  assert_success
  assert_output "my_project"
}

@test "_to_package_name: mixed hyphens and dots" {
  run _to_package_name "my-cool.service"
  assert_success
  assert_output "my_cool_service"
}

@test "_to_package_name: already clean name passes through" {
  run _to_package_name "myproject"
  assert_success
  assert_output "myproject"
}

@test "_to_package_name: underscores preserved" {
  run _to_package_name "my_project"
  assert_success
  assert_output "my_project"
}

@test "_to_package_name: leading digit gets underscore prefix" {
  run _to_package_name "121"
  assert_success
  assert_output "_121"
}

@test "_to_package_name: leading digit after normalization gets underscore prefix" {
  run _to_package_name "123.my-service"
  assert_success
  assert_output "_123_my_service"
}

@test "_to_package_name: empty string returns empty" {
  run _to_package_name ""
  assert_success
  assert_output ""
}
