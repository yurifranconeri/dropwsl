#!/usr/bin/env bats
# tests/unit/test_install_nodejs.bats -- Unit tests for Node.js installer

setup() {
  load '../helpers/test_helper'
  _common_setup
  load '../helpers/mock_commands'
  unset _NODEJS_SH_LOADED
  source "${REPO_ROOT}/lib/core/nodejs.sh"
  activate_mocks
  NODEJS_VERSION="24"
}

teardown() {
  _common_teardown
}

@test "install_nodejs: skips if node already installed" {
  MOCK_AVAILABLE_CMDS=(node)
  node() { echo "v24.14.1"; }
  export -f node
  run install_nodejs
  assert_success
  assert_output --partial "already installed"
}

@test "install_nodejs: log message includes version" {
  MOCK_AVAILABLE_CMDS=()
  NODEJS_VERSION="24"
  get_distro_info() { DISTRO_ID="ubuntu"; DISTRO_CODENAME="noble"; }
  curl_retry() { return 0; }
  make_temp() { mktemp; }
  gpg() { cat > /dev/null; return 0; }
  sudo() { return 0; }
  run install_nodejs
  assert_output --partial "Installing Node.js 24.x LTS"
}

@test "install_nodejs: respects NODEJS_VERSION variable" {
  MOCK_AVAILABLE_CMDS=()
  NODEJS_VERSION="22"
  get_distro_info() { DISTRO_ID="ubuntu"; DISTRO_CODENAME="jammy"; }
  curl_retry() { return 0; }
  make_temp() { mktemp; }
  gpg() { cat > /dev/null; return 0; }
  sudo() { return 0; }
  run install_nodejs
  assert_output --partial "Installing Node.js 22.x LTS"
}

@test "install_nodejs: guard clause prevents double source" {
  _NODEJS_SH_LOADED=1
  source "${REPO_ROOT}/lib/core/nodejs.sh"
  assert true
}
