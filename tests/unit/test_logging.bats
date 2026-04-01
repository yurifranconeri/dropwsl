#!/usr/bin/env bats
# tests/unit/test_logging.bats — Tests for log(), warn(), die(), run_quiet()

setup() {
  load '../helpers/test_helper'
  _common_setup
}

teardown() {
  _common_teardown
}

@test "log: stdout contains ==> and message" {
  run log "test log message"
  assert_success
  assert_output --partial "==> test log message"
}

@test "warn: stderr contains [WARN] and message" {
  run warn "important warning"
  assert_success
  assert_output --partial "[WARN] important warning"
}

@test "die: exit code 1" {
  run die "fatal error"
  assert_failure 1
}

@test "die: stderr contains [ERROR] and message" {
  run die "fatal error"
  assert_output --partial "[ERROR] fatal error"
}

@test "log with active LOG_FILE writes to file" {
  local logfile="${TEST_TEMP}/test.log"
  LOG_FILE="$logfile"
  log "message for file"
  assert [ -f "$logfile" ]
  grep -q "==> message for file" "$logfile"
  LOG_FILE="/dev/null"
}

@test "warn with active LOG_FILE writes to file" {
  local logfile="${TEST_TEMP}/test.log"
  LOG_FILE="$logfile"
  warn "warning for file"
  grep -q "\\[WARN\\] warning for file" "$logfile"
  LOG_FILE="/dev/null"
}

@test "run_quiet with QUIET=true suppresses stdout" {
  QUIET=true
  run run_quiet echo "should disappear"
  assert_success
  refute_output --partial "should disappear"
}

@test "run_quiet with QUIET=false shows stdout" {
  QUIET=false
  LOG_FILE=""
  run run_quiet echo "should appear"
  assert_success
  assert_output --partial "should appear"
  QUIET=true
}
