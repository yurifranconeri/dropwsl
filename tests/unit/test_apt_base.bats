#!/usr/bin/env bats
# tests/unit/test_apt_base.bats -- Tests for apt_base() base package list
#
# apt_base() declares base_pkgs as a local array, so we assert via source
# inspection rather than runtime introspection.

setup() {
  load '../helpers/test_helper'
  _common_setup
}

teardown() {
  _common_teardown
}

@test "apt_base: declares base_pkgs array" {
  run grep -E '^\s*local base_pkgs=\(' "${REPO_ROOT}/lib/common.sh"
  assert_success
}

@test "apt_base: includes ca-certificates" {
  run grep -F 'ca-certificates' "${REPO_ROOT}/lib/common.sh"
  assert_success
}

@test "apt_base: includes curl" {
  run grep -E 'base_pkgs=\([^)]*\bcurl\b' "${REPO_ROOT}/lib/common.sh"
  assert_success
}

@test "apt_base: includes git" {
  run grep -E 'base_pkgs=\([^)]*\bgit\b' "${REPO_ROOT}/lib/common.sh"
  assert_success
}

@test "apt_base: includes unzip (bun support)" {
  run grep -E 'base_pkgs=\([^)]*\bunzip\b' "${REPO_ROOT}/lib/common.sh"
  assert_success
}

@test "apt_base: includes bind9-dnsutils (dig/host/nslookup)" {
  run grep -E 'base_pkgs=\([^)]*\bbind9-dnsutils\b' "${REPO_ROOT}/lib/common.sh"
  assert_success
}
