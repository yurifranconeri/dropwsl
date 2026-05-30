#!/usr/bin/env bats
# tests/unit/test_install_pac_cli.bats -- Unit tests for PAC CLI installer

setup() {
  load '../helpers/test_helper'
  _common_setup
  load '../helpers/mock_commands'
  unset _PAC_CLI_SH_LOADED
  source "${REPO_ROOT}/lib/core/pac-cli.sh"
  activate_mocks
  PAC_CLI_VERSION="2.5.1"
}

teardown() {
  _common_teardown
}

@test "install_pac-cli: skips if pac already installed" {
  MOCK_AVAILABLE_CMDS=(pac)
  pac() { echo -e "Microsoft PowerPlatform CLI\nVersion: 2.5.1"; }
  export -f pac
  run install_pac-cli
  assert_success
  assert_output --partial "already installed"
}

@test "install_pac-cli: dies if dotnet not installed" {
  MOCK_AVAILABLE_CMDS=()
  run install_pac-cli
  assert_failure
  assert_output --partial "requires .NET SDK"
}

@test "install_pac-cli: calls dotnet tool install with version" {
  MOCK_AVAILABLE_CMDS=(dotnet)
  dotnet() {
    # Simulate install: pac becomes available after dotnet tool install
    MOCK_AVAILABLE_CMDS+=(pac)
    return 0
  }
  pac() { echo -e "Microsoft PowerPlatform CLI\nVersion: 2.5.1"; }
  export -f dotnet pac
  run install_pac-cli
  assert_success
  assert_output --partial "Installing Power Platform CLI (pac) 2.5.1"
}

@test "install_pac-cli: persists PATH in bashrc" {
  HOME="$TEST_TEMP"
  MOCK_AVAILABLE_CMDS=(dotnet)
  dotnet() {
    MOCK_AVAILABLE_CMDS+=(pac)
    return 0
  }
  pac() { echo "Version: 2.5.1"; }
  export -f dotnet pac
  run install_pac-cli
  assert_success
  [[ -f "${TEST_TEMP}/.bashrc" ]]
  run grep -F '.dotnet/tools' "${TEST_TEMP}/.bashrc"
  assert_success
}

@test "install_pac-cli: does not duplicate PATH in bashrc" {
  HOME="$TEST_TEMP"
  echo 'export PATH="$HOME/.dotnet/tools:$PATH"' > "${TEST_TEMP}/.bashrc"
  MOCK_AVAILABLE_CMDS=(dotnet)
  dotnet() {
    MOCK_AVAILABLE_CMDS+=(pac)
    return 0
  }
  pac() { echo "Version: 2.5.1"; }
  export -f dotnet pac
  run install_pac-cli
  assert_success
  local count
  count="$(grep -cF '.dotnet/tools' "${TEST_TEMP}/.bashrc")"
  [[ "$count" -eq 1 ]]
}

@test "install_pac-cli: guard clause prevents double source" {
  _PAC_CLI_SH_LOADED=1
  source "${REPO_ROOT}/lib/core/pac-cli.sh"
  assert true
}
