#!/usr/bin/env bats
# tests/unit/test_install_vscode_extensions.bats -- Unit tests for install_vscode_extensions

setup() {
  load '../helpers/test_helper'
  _common_setup
  load '../helpers/mock_commands'
  unset _VSCODE_SH_LOADED
  source "${REPO_ROOT}/lib/core/vscode.sh"
  activate_mocks
  VSCODE_EXTENSIONS=(some.extension)

  # Capture cmd.exe invocations
  export CMD_LOG="${BATS_TEST_TMPDIR}/cmd.log"
  : > "$CMD_LOG"
  cmd.exe() {
    echo "$*" >> "$CMD_LOG"
    case "$*" in
      *"code --version"*) echo "1.117.0"; return 0 ;;
      *"--install-extension"*) echo "Extension 'some.extension' was successfully installed."; return 0 ;;
    esac
    return 0
  }
  export -f cmd.exe
  MOCK_AVAILABLE_CMDS=(cmd.exe)
}

teardown() {
  _common_teardown
}

@test "install_vscode_extensions: passes --force to code --install-extension" {
  run install_vscode_extensions
  assert_success
  run grep -F -- '--install-extension some.extension --force' "$CMD_LOG"
  assert_success
}

@test "install_vscode_extensions: skips when cmd.exe is missing" {
  MOCK_AVAILABLE_CMDS=()
  run install_vscode_extensions
  assert_success
  assert_output --partial "cmd.exe not found"
}

@test "install_vscode_extensions: warns when code is not on PATH" {
  cmd.exe() {
    case "$*" in
      *"code --version"*) return 1 ;;
    esac
    return 0
  }
  export -f cmd.exe
  run install_vscode_extensions
  assert_success
  assert_output --partial "VS Code (code) not found"
}
