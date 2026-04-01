#!/usr/bin/env bats
# tests/unit/test_sed_escape.bats — Tests for _sed_escape()

setup() {
  load '../helpers/test_helper'
  _common_setup
}

teardown() {
  _common_teardown
}

@test "_sed_escape: plain string passes through unchanged" {
  run _sed_escape "hello-world"
  assert_success
  assert_output "hello-world"
}

@test "_sed_escape: escapes ampersand" {
  run _sed_escape "foo&bar"
  assert_success
  assert_output 'foo\&bar'
}

@test "_sed_escape: escapes pipe" {
  run _sed_escape "foo|bar"
  assert_success
  assert_output 'foo\|bar'
}

@test "_sed_escape: escapes backslash" {
  run _sed_escape 'foo\bar'
  assert_success
  assert_output 'foo\\bar'
}

@test "_sed_escape: escapes all three combined" {
  run _sed_escape 'a\b&c|d'
  assert_success
  assert_output 'a\\b\&c\|d'
}

@test "_sed_escape: empty string returns empty" {
  run _sed_escape ""
  assert_success
  assert_output ""
}

@test "_sed_escape: result is safe for sed substitution" {
  local tmp
  tmp="$(mktemp)"
  echo "PLACEHOLDER" > "$tmp"
  local safe; safe="$(_sed_escape 'val&with|pipe\slash')"
  sed -i "s|PLACEHOLDER|${safe}|g" "$tmp"
  run cat "$tmp"
  assert_success
  assert_output 'val&with|pipe\slash'
  rm -f "$tmp"
}
