#!/usr/bin/env bats
# tests/uninstall/test_unregister.bats -- Destructive: destroys the WSL distro
#
# REQUIREMENTS:
#   - Runs inside WSL (invokes powershell.exe via interop)
#   - Admin privileges on Windows side
#   - Should run AFTER test_clean_soft
#
# AFTER THIS TEST: distro is destroyed. WSL platform remains.
# To restore: install.cmd (as Admin)
#
# NOTE: The final test (wsl --unregister) terminates the WSL session.
# bats cannot observe the result from inside WSL — the test validates
# the pre-conditions and invokes the command. Verification must happen
# from Windows (Test-DistroInstalled returns $false).

setup() {
  load '../helpers/test_helper'
  _common_setup
}

teardown() {
  _common_teardown
}

@test "pre-unregister: WSL_DISTRO_NAME is set" {
  [[ -n "${WSL_DISTRO_NAME:-}" ]]
}

@test "pre-unregister: distro is in wsl --list" {
  # Call Windows-side wsl.exe to list distros
  run wsl.exe --list --quiet
  assert_success
  assert_output --partial "${WSL_DISTRO_NAME}"
}

@test "pre-unregister: uninstall.ps1 exists" {
  local repo_root="${REPO_ROOT}"
  [[ -f "${repo_root}/uninstall.ps1" ]]
}

@test "unregister: dry-run succeeds (WhatIf)" {
  # WhatIf shows what would happen without executing
  run powershell.exe -NoProfile -ExecutionPolicy Bypass \
    -File "${REPO_ROOT}/uninstall.ps1" -Unregister -Force -WhatIf 2>&1
  # Exit 0 = script parsed and ran dry-run without error
  assert_success
}

# CAUTION: This test DESTROYS the distro. It is the last test in this file.
# bats will lose its session when the distro is unregistered.
# The test is tagged so it can be excluded: --filter-tags '!destructive'
# bats test_tags=destructive
@test "unregister: executes wsl --unregister" {
  # This invokes the real unregister from Windows side.
  # The WSL session will terminate — bats exit code will be lost.
  # We rely on the Windows-side Pester test to verify the result.
  skip "Run from Windows: .\\uninstall.cmd -Unregister -Force"
}
