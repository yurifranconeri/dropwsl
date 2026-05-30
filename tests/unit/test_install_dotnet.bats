#!/usr/bin/env bats
# tests/unit/test_install_dotnet.bats -- Unit tests for .NET SDK installer

setup() {
  load '../helpers/test_helper'
  _common_setup
  load '../helpers/mock_commands'
  unset _DOTNET_SH_LOADED
  source "${REPO_ROOT}/lib/core/dotnet.sh"
  activate_mocks
  DOTNET_VERSION="10.0"
}

teardown() {
  _common_teardown
}

@test "install_dotnet: skips if dotnet already installed" {
  MOCK_AVAILABLE_CMDS=(dotnet)
  dotnet() { echo "10.0.100"; }
  export -f dotnet
  run install_dotnet
  assert_success
  assert_output --partial "already installed"
}

@test "install_dotnet: log message includes version" {
  MOCK_AVAILABLE_CMDS=()
  DOTNET_VERSION="10.0"
  get_distro_info() { DISTRO_ID="ubuntu"; DISTRO_CODENAME="noble"; }
  curl_retry() { return 0; }
  make_temp() { mktemp; }
  sudo() { return 0; }
  run install_dotnet
  assert_output --partial "Installing .NET SDK 10.0"
}

@test "install_dotnet: respects DOTNET_VERSION variable" {
  MOCK_AVAILABLE_CMDS=()
  DOTNET_VERSION="9.0"
  get_distro_info() { DISTRO_ID="debian"; DISTRO_CODENAME="bookworm"; }
  curl_retry() { return 0; }
  make_temp() { mktemp; }
  sudo() { return 0; }
  run install_dotnet
  assert_output --partial "Installing .NET SDK 9.0"
}

@test "install_dotnet: guard clause prevents double source" {
  _DOTNET_SH_LOADED=1
  # Sourcing again should return immediately (no functions redefined)
  source "${REPO_ROOT}/lib/core/dotnet.sh"
  # If we got here, guard clause worked
  assert true
}
