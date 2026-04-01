#!/usr/bin/env bats
# tests/uninstall/test_purge.bats -- Destructive: removes WSL platform
#
# REQUIREMENTS:
#   - Runs inside WSL (but can only validate pre-conditions)
#   - Admin privileges on Windows side
#   - Should run AFTER test_unregister
#
# AFTER THIS TEST: WSL is uninstalled from Windows.
# To restore: install.cmd (as Admin)
#
# NOTE: Purge removes WSL itself — cannot be executed or observed from
# inside WSL. These tests validate pre-conditions only. The actual
# purge must be run from Windows.

setup() {
  load '../helpers/test_helper'
  _common_setup
}

teardown() {
  _common_teardown
}

@test "pre-purge: wsl.exe is available" {
  run command -v wsl.exe
  assert_success
}

@test "pre-purge: uninstall.ps1 -Purge dry-run succeeds" {
  run powershell.exe -NoProfile -ExecutionPolicy Bypass \
    -File "${REPO_ROOT}/uninstall.ps1" -Purge -Force -WhatIf 2>&1
  assert_success
}

# CAUTION: This test REMOVES WSL from Windows.
# bats test_tags=destructive
@test "purge: executes wsl --uninstall" {
  skip "Run from Windows: .\\uninstall.cmd -Purge -Force"
}
