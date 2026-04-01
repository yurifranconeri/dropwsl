#!/usr/bin/env bash
# tests/helpers/test_helper.bash — Shared setup for all .bats
# Loaded via: load '../helpers/test_helper' (or '../../helpers/test_helper')
#
# IMPORTANT: Do NOT define setup()/teardown() here — they would be overwritten
# by the test file (bats uses the last definition). Use _common_setup/_common_teardown
# which each test file calls explicitly.

BATS_TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
REPO_ROOT="$(cd "$BATS_TEST_DIR" && while [[ ! -f dropwsl.sh ]] && [[ "$PWD" != "/" ]]; do cd ..; done; pwd)"

# bats libraries
load "${REPO_ROOT}/tests/bats/bats-support/load"
load "${REPO_ROOT}/tests/bats/bats-assert/load"

# Prevent side-effects: redirect logs to /dev/null
export LOG_FILE="/dev/null"
export QUIET=true
export ASSUME_YES=true
export DEBIAN_FRONTEND=noninteractive

# SCRIPT_DIR is needed for common.sh to find layers and templates
export SCRIPT_DIR="$REPO_ROOT"

# Source common.sh (defines all functions). Deactivate guard clause if re-source.
unset _COMMON_SH_LOADED
source "${REPO_ROOT}/lib/common.sh"

# Strip ANSI color codes to make output testable.
# The real functions (log, warn, die, die_hint) use \033[xxm inline.
# We redefine here without colors — we test format and content, not colors.
log()  { echo "==> $*"; [[ -n "${LOG_FILE:-}" && "${LOG_FILE:-}" != "/dev/null" ]] && echo "==> $*" >> "$LOG_FILE" || true; }
warn() { echo "[WARN] $*" >&2; [[ -n "${LOG_FILE:-}" && "${LOG_FILE:-}" != "/dev/null" ]] && echo "[WARN] $*" >> "$LOG_FILE" || true; }
die()  { echo "[ERROR] $*" >&2; [[ -n "${LOG_FILE:-}" && "${LOG_FILE:-}" != "/dev/null" ]] && echo "[ERROR] $*" >> "$LOG_FILE" || true; exit 1; }
die_hint() {
  local msg="$1" causes="$2" solutions="$3" manual="${4:-}"
  echo "" >&2
  echo "[ERROR] $msg" >&2
  echo "" >&2
  echo "  Probable causes:" >&2
  local IFS=';'
  local item
  set -f
  for item in $causes; do
    item="$(echo "$item" | sed 's/^[[:space:]]*//')"
    [[ -n "$item" ]] && echo "    • $item" >&2
  done
  echo "" >&2
  echo "  Solutions:" >&2
  local i=1
  for item in $solutions; do
    item="$(echo "$item" | sed 's/^[[:space:]]*//')"
    [[ -n "$item" ]] && { echo "    $i. $item" >&2; ((i++)); }
  done
  set +f
  if [[ -n "$manual" ]]; then
    echo "" >&2
    echo "  Manual verification:" >&2
    echo "    \$ $manual" >&2
  fi
  echo "" >&2
  exit 1
}

_common_setup() {
  TEST_TEMP="$(mktemp -d)"
  export TEST_TEMP
}

_common_teardown() {
  [[ -d "${TEST_TEMP:-}" ]] && rm -rf "$TEST_TEMP"
  return 0
}
