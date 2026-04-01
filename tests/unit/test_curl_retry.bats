#!/usr/bin/env bats
# tests/unit/test_curl_retry.bats — Tests for curl_retry() with mock

setup() {
  load '../helpers/test_helper'
  _common_setup
  # Save original curl
  ORIG_CURL="$(command -v curl || true)"
}

teardown() {
  _common_teardown
}

@test "curl_retry: success on 1st attempt" {
  # Mock curl that always works
  curl() { echo "ok"; return 0; }
  export -f curl
  run curl_retry -s "http://example.com"
  assert_success
  assert_output --partial "ok"
}

@test "curl_retry: total failure → die_hint" {
  # Mock curl that always fails
  curl() { return 1; }
  export -f curl
  # Also mock sleep to avoid waiting
  sleep() { return 0; }
  export -f sleep
  run curl_retry -s "http://example.com"
  assert_failure
  assert_output --partial "curl failed"
}
