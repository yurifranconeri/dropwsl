#!/usr/bin/env bats
# tests/unit/test_parse_args.bats — Unit tests for _parse_args (dropwsl.sh)

load '../helpers/test_helper'

# bats' load() runs source inside a function scope, so declare -A in common.sh
# creates GIT_DEFAULTS as local to that scope. Re-declare at top-level before
# sourcing dropwsl.sh (which calls load_config and assigns to GIT_DEFAULTS).
declare -A GIT_DEFAULTS 2>/dev/null || true

# Source dropwsl.sh to get _parse_args. The guard at the bottom
# ([[ BASH_SOURCE[0] == $0 ]]) prevents main() from running.
# Modules (common.sh, validate.sh, etc.) are already sourced by test_helper,
# but the guard clauses (_COMMON_SH_LOADED etc.) make re-sourcing harmless.
source "${REPO_ROOT}/dropwsl.sh"

# Reset all variables that _parse_args populates (mirrors main() declarations).
_reset_parse_state() {
  action=""
  action_args=()
  with_layers=""
  service_name=""
  _want_help=false
  _want_version=false
  _has_unregister=false
  _has_purge=false
  QUIET=false
  ASSUME_YES=false
  NO_DEFAULTS=false
}

setup() { _common_setup; _reset_parse_state; }
teardown() { _common_teardown; }

# ---- T1: no arguments → defaults ------------------------------------------------

@test "_parse_args: no arguments keeps defaults" {
  _parse_args
  assert_equal "$action" ""
  assert_equal "$with_layers" ""
  assert_equal "$service_name" ""
  assert_equal "$_want_help" "false"
  assert_equal "$_want_version" "false"
  assert_equal "$QUIET" "false"
  assert_equal "$ASSUME_YES" "false"
  assert_equal "$NO_DEFAULTS" "false"
}

# ---- T2: --quiet and --yes set globals -------------------------------------------

@test "_parse_args: --quiet sets QUIET" {
  _parse_args --quiet
  assert_equal "$QUIET" "true"
}

@test "_parse_args: -q sets QUIET" {
  _parse_args -q
  assert_equal "$QUIET" "true"
}

@test "_parse_args: --yes sets ASSUME_YES" {
  _parse_args --yes
  assert_equal "$ASSUME_YES" "true"
}

@test "_parse_args: -y sets ASSUME_YES" {
  _parse_args -y
  assert_equal "$ASSUME_YES" "true"
}

@test "_parse_args: --no-defaults sets NO_DEFAULTS" {
  _parse_args --no-defaults
  assert_equal "$NO_DEFAULTS" "true"
}

# ---- T3: positional action + action_args -----------------------------------------

@test "_parse_args: bare action is captured" {
  _parse_args validate
  assert_equal "$action" "validate"
}

@test "_parse_args: new with positional args" {
  _parse_args new myproject python
  assert_equal "$action" "new"
  assert_equal "${action_args[0]}" "myproject"
  assert_equal "${action_args[1]}" "python"
}

@test "_parse_args: dashed action --validate strips prefix" {
  _parse_args --validate
  assert_equal "$action" "validate"
}

@test "_parse_args: dashed action --new with args" {
  _parse_args --new myproject python
  assert_equal "$action" "new"
  assert_equal "${action_args[0]}" "myproject"
  assert_equal "${action_args[1]}" "python"
}

# ---- T4: --with (separate arguments and =syntax) ---------------------------------

@test "_parse_args: --with single layer" {
  _parse_args new svc python --with src
  assert_equal "$with_layers" "src"
}

@test "_parse_args: --with multiple layers space-separated" {
  _parse_args new svc python --with src fastapi uv
  assert_equal "$with_layers" "src,fastapi,uv"
}

@test "_parse_args: --with=comma-separated" {
  _parse_args new svc python --with=src,fastapi,uv
  assert_equal "$with_layers" "src,fastapi,uv"
}

@test "_parse_args: --with stops collecting on next flag" {
  _parse_args new svc python --with src fastapi --quiet
  assert_equal "$with_layers" "src,fastapi"
  assert_equal "$QUIET" "true"
}

@test "_parse_args: --with comma+space mix normalizes cleanly" {
  _parse_args new svc python --with fastapi, src, redis, postgres
  assert_equal "$with_layers" "fastapi,src,redis,postgres"
}

# ---- T5: --service ---------------------------------------------------------------

@test "_parse_args: --service captures name" {
  _parse_args new plat --service api python
  assert_equal "$service_name" "api"
}

@test "_parse_args: --service=name captures name" {
  _parse_args new plat --service=api python
  assert_equal "$service_name" "api"
}

# ---- T6: --help / --version flags ------------------------------------------------

@test "_parse_args: --help sets _want_help" {
  _parse_args --help
  assert_equal "$_want_help" "true"
}

@test "_parse_args: -h sets _want_help" {
  _parse_args -h
  assert_equal "$_want_help" "true"
}

@test "_parse_args: --version sets _want_version" {
  _parse_args --version
  assert_equal "$_want_version" "true"
}

@test "_parse_args: -v sets _want_version" {
  _parse_args -v
  assert_equal "$_want_version" "true"
}

# ---- T7: uninstall flags ---------------------------------------------------------

@test "_parse_args: uninstall --unregister" {
  _parse_args uninstall --unregister
  assert_equal "$action" "uninstall"
  assert_equal "$_has_unregister" "true"
}

@test "_parse_args: uninstall --tools" {
  _parse_args uninstall --tools
  assert_equal "$action" "uninstall"
  assert_equal "$_has_tools" "true"
}

@test "_parse_args: uninstall --full (alias for --unregister)" {
  _parse_args uninstall --full
  assert_equal "$_has_unregister" "true"
}

@test "_parse_args: uninstall --purge" {
  _parse_args uninstall --purge
  assert_equal "$_has_purge" "true"
}

@test "_parse_args: uninstall --remove-wsl (alias for --purge)" {
  _parse_args uninstall --remove-wsl
  assert_equal "$_has_purge" "true"
}

# ---- T8: combined flags ----------------------------------------------------------

@test "_parse_args: combined flags in any order" {
  _parse_args -q -y validate
  assert_equal "$QUIET" "true"
  assert_equal "$ASSUME_YES" "true"
  assert_equal "$action" "validate"
}

@test "_parse_args: flags after action" {
  _parse_args validate --quiet --yes
  assert_equal "$action" "validate"
  assert_equal "$QUIET" "true"
  assert_equal "$ASSUME_YES" "true"
}

@test "_parse_args: full new command with all options" {
  _parse_args -q new plat --service api python --with src,fastapi --no-defaults
  assert_equal "$QUIET" "true"
  assert_equal "$NO_DEFAULTS" "true"
  assert_equal "$action" "new"
  assert_equal "${action_args[0]}" "plat"
  assert_equal "$service_name" "api"
  assert_equal "${action_args[1]}" "python"
  assert_equal "$with_layers" "src,fastapi"
}

# ---- T9: unknown flags are ignored (no crash) ------------------------------------

@test "_parse_args: unknown --flag does not crash" {
  _parse_args --unknown-flag validate
  assert_equal "$action" "validate"
}

# ---- T10: edge cases --------------------------------------------------------------

@test "_parse_args: --with with no following args yields empty" {
  _parse_args new svc python --with
  assert_equal "$with_layers" ""
}

@test "_parse_args: install action explicitly" {
  _parse_args install
  assert_equal "$action" "install"
}

# ---- T11: single-dash flags must not be collected as layers (bug #128) --------

@test "_parse_args: -y after --with stops collecting (positional arg not leaked as layer)" {
  _parse_args new svc python --with src -y morearg
  assert_equal "$with_layers" "src"
  assert_equal "$ASSUME_YES" "true"
  # morearg must be captured as action_arg, NOT as a layer
  assert_equal "${action_args[2]}" "morearg"
}

@test "_parse_args: -q after --with stops collecting (positional arg not leaked as layer)" {
  _parse_args new svc python --with fastapi -q morearg
  assert_equal "$with_layers" "fastapi"
  assert_equal "$QUIET" "true"
  assert_equal "${action_args[2]}" "morearg"
}

# ---- T12: --with= appends instead of overwriting (bug #1 audit) -----------------

@test "_parse_args: multiple --with= flags append layers" {
  _parse_args new svc python --with=src --with=redis
  assert_equal "$with_layers" "src,redis"
}

@test "_parse_args: --with= after --with positional appends" {
  _parse_args new svc python --with src --with=redis
  assert_equal "$with_layers" "src,redis"
}

@test "_parse_args: --with= after --with= appends three" {
  _parse_args new svc python --with=src,fastapi --with=uv --with=postgres
  assert_equal "$with_layers" "src,fastapi,uv,postgres"
}

# ---- T13: --service= resets collecting_service (bug #2 audit) --------------------

@test "_parse_args: --service=name resets collecting_service flag" {
  # Edge: --service (starts collecting) then --service=api (should reset)
  # Next positional must become action_arg, NOT service_name
  _parse_args new plat --service --service=api python
  assert_equal "$service_name" "api"
  assert_equal "${action_args[1]}" "python"
}

# ---- T14: unknown flags emit warning (audit #3) ---------------------------------

@test "_parse_args: unknown --flag emits warning" {
  run _parse_args --validaet
  # warn writes to stderr; run captures both
  assert_output --partial "Unknown flag: --validaet"
}
