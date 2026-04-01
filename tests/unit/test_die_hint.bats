#!/usr/bin/env bats
# tests/unit/test_die_hint.bats — Tests for die_hint()

setup() {
  load '../helpers/test_helper'
  _common_setup
}

teardown() {
  _common_teardown
}

@test "die_hint: exit code 1" {
  run die_hint "error" "cause1" "solution1"
  assert_failure 1
}

@test "die_hint: shows error message" {
  run die_hint "general failure" "cause1" "solution1"
  assert_output --partial "[ERROR] general failure"
}

@test "die_hint: shows probable causes" {
  run die_hint "msg" "cause alpha;cause beta" "fix1"
  assert_output --partial "cause alpha"
  assert_output --partial "cause beta"
}

@test "die_hint: shows numbered solutions" {
  run die_hint "msg" "cause1" "solution A;solution B;solution C"
  assert_output --partial "1. solution A"
  assert_output --partial "2. solution B"
  assert_output --partial "3. solution C"
}

@test "die_hint: causes with * and ? do not expand as glob" {
  run die_hint "msg" "file *.txt not found;pattern ? failed" "sol1"
  assert_output --partial "*.txt"
  assert_output --partial "pattern ?"
}

@test "die_hint: with manual command" {
  run die_hint "msg" "cause" "fix" "docker info"
  assert_output --partial "docker info"
}

@test "die_hint: without manual command omits section" {
  run die_hint "msg" "cause" "fix"
  assert_failure 1
  refute_output --partial "Manual verification"
}
