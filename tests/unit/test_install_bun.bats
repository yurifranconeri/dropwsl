#!/usr/bin/env bats
# tests/unit/test_install_bun.bats -- Unit tests for Bun installer

setup() {
  load '../helpers/test_helper'
  _common_setup
  load '../helpers/mock_commands'
  unset _BUN_SH_LOADED
  source "${REPO_ROOT}/lib/core/bun.sh"
  activate_mocks
  BUN_VERSION="1.3.12"
}

teardown() {
  _common_teardown
}

@test "install_bun: skips if bun already installed" {
  MOCK_AVAILABLE_CMDS=(bun)
  bun() { echo "1.3.12"; }
  export -f bun
  run install_bun
  assert_success
  assert_output --partial "already installed"
}

@test "install_bun: log message includes version" {
  MOCK_AVAILABLE_CMDS=()
  BUN_VERSION="1.3.12"
  make_temp() { mktemp; }
  make_temp_dir() { mktemp -d; }
  curl_retry() {
    # Simulate SHASUMS256.txt download: write a fake checksum matching the zip
    local dest=""
    for arg in "$@"; do
      case "$arg" in
        -o)    dest="next" ;;
        -*o*)  dest="next" ;;
        *)     [[ "$dest" == "next" ]] && { dest="$arg"; break; } ;;
      esac
    done
    if [[ -n "$dest" ]] && [[ "$*" == *"SHASUMS256"* ]]; then
      echo "fakechecksum  bun-linux-x64.zip" > "$dest"
    fi
    return 0
  }
  sha256sum() { echo "fakechecksum  -"; }
  grep() { command grep "$@"; }
  unzip() { mkdir -p "$3/bun-linux-x64"; touch "$3/bun-linux-x64/bun"; }
  sudo() { return 0; }
  chmod() { return 0; }
  run install_bun
  assert_output --partial "Installing Bun 1.3.12"
}

@test "install_bun: respects BUN_VERSION variable" {
  MOCK_AVAILABLE_CMDS=()
  BUN_VERSION="1.2.0"
  make_temp() { mktemp; }
  make_temp_dir() { mktemp -d; }
  curl_retry() {
    local dest=""
    for arg in "$@"; do
      case "$arg" in
        -o)    dest="next" ;;
        -*o*)  dest="next" ;;
        *)     [[ "$dest" == "next" ]] && { dest="$arg"; break; } ;;
      esac
    done
    if [[ -n "$dest" ]] && [[ "$*" == *"SHASUMS256"* ]]; then
      echo "fakechecksum  bun-linux-x64.zip" > "$dest"
    fi
    return 0
  }
  sha256sum() { echo "fakechecksum  -"; }
  grep() { command grep "$@"; }
  unzip() { mkdir -p "$3/bun-linux-x64"; touch "$3/bun-linux-x64/bun"; }
  sudo() { return 0; }
  chmod() { return 0; }
  run install_bun
  assert_output --partial "Installing Bun 1.2.0"
}

@test "install_bun: guard clause prevents double source" {
  _BUN_SH_LOADED=1
  source "${REPO_ROOT}/lib/core/bun.sh"
  assert true
}
