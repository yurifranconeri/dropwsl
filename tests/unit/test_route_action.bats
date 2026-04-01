#!/usr/bin/env bats
# tests/unit/test_route_action.bats — Tests for dropwsl.sh routing (unknown cmd, uninstall help)

load '../helpers/test_helper'

# bats' load() runs source inside a function scope, so declare -A in common.sh
# creates GIT_DEFAULTS as local to that scope. Re-declare at top-level before
# sourcing dropwsl.sh (which calls load_config and assigns to GIT_DEFAULTS).
declare -A GIT_DEFAULTS 2>/dev/null || true

# Source dropwsl.sh once at top-level so function tests don't depend on setup()
# scoping quirks from bats.
source "${REPO_ROOT}/dropwsl.sh"

setup() {
  _common_setup
}

teardown() {
  _common_teardown
}

# ---------------------------------------------------------------------------
# Unknown command emits warning + exit 1
# ---------------------------------------------------------------------------
@test "route: unknown command exits 1" {
  run main "unistal"
  assert_failure
}

@test "route: unknown command shows warning with command name" {
  run main "foobar"
  assert_failure
  assert_output --partial "Unknown command: foobar"
}

# ---------------------------------------------------------------------------
# uninstall --help shows specific help
# ---------------------------------------------------------------------------
@test "route: uninstall --help shows uninstall-specific help" {
  run main "uninstall" "--help"
  assert_success
  assert_output --partial "--tools"
  assert_output --partial "--unregister"
  assert_output --partial "--purge"
}

@test "route: uninstall --help does not show generic usage" {
  run main "uninstall" "--help"
  assert_success
  # Generic usage has "dropwsl <command>" — uninstall help should not
  refute_output --partial "dropwsl <command>"
}

@test "route: uninstall -h is alias for --help" {
  run main "uninstall" "-h"
  assert_success
  assert_output --partial "--tools"
}
