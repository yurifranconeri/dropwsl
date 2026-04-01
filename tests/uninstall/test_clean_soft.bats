#!/usr/bin/env bats
# tests/uninstall/test_clean_soft.bats -- Destructive: removes all dropwsl tools
#
# REQUIREMENTS:
#   - Runs inside WSL with dropwsl fully provisioned
#   - sudo access
#   - MUST run BEFORE test_unregister (distro still exists)
#
# AFTER THIS TEST: tools are gone, distro is intact.
# To restore: ./dropwsl.sh (or install.cmd from Windows)

setup() {
  load '../helpers/test_helper'
  _common_setup
  unset _CLEAN_SH_LOADED _VALIDATE_SH_LOADED
  source "${REPO_ROOT}/lib/clean.sh"
  source "${REPO_ROOT}/lib/validate.sh"
}

teardown() {
  _common_teardown
}

# ---- Pre-flight: confirm tools exist before removal ----

@test "pre-clean: docker is installed" {
  run command -v docker
  assert_success
}

@test "pre-clean: kubectl is installed" {
  run command -v kubectl
  assert_success
}

@test "pre-clean: kind is installed" {
  run command -v kind
  assert_success
}

@test "pre-clean: helm is installed" {
  run command -v helm
  assert_success
}

# ---- Execute clean-soft ----

@test "clean-soft: runs without error" {
  export ASSUME_YES=true
  run clean_soft
  assert_success
}

# ---- Post-clean: verify tools are gone ----

@test "post-clean: docker removed" {
  run command -v docker
  assert_failure
}

@test "post-clean: kubectl removed" {
  run command -v kubectl
  assert_failure
}

@test "post-clean: kind removed" {
  run command -v kind
  assert_failure
}

@test "post-clean: helm removed" {
  run command -v helm
  assert_failure
}

@test "post-clean: az cli removed" {
  run command -v az
  assert_failure
}

@test "post-clean: gh cli removed" {
  run command -v gh
  assert_failure
}

@test "post-clean: GCM git config unset" {
  local helper
  helper="$(git config --global credential.helper 2>/dev/null || true)"
  [[ "$helper" != *"git-credential-manager"* ]]
}

@test "post-clean: symlink preserved" {
  [[ -L "${HOME}/.local/bin/dropwsl" ]]
}

@test "post-clean: apt sources cleaned" {
  [[ ! -f /etc/apt/sources.list.d/docker.list ]]
  [[ ! -f /etc/apt/sources.list.d/kubernetes.list ]]
  [[ ! -f /etc/apt/sources.list.d/azure-cli.list ]]
  [[ ! -f /etc/apt/sources.list.d/github-cli.list ]]
}

@test "post-clean: apt keyrings cleaned" {
  [[ ! -f /etc/apt/keyrings/docker.gpg ]]
  [[ ! -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg ]]
  [[ ! -f /etc/apt/keyrings/microsoft.gpg ]]
  [[ ! -f /etc/apt/keyrings/githubcli-archive-keyring.gpg ]]
}

@test "post-clean: daemon.json removed" {
  [[ ! -f /etc/docker/daemon.json ]]
}

@test "post-clean: install dir preserved" {
  [[ -d "${HOME}/.local/share/dropwsl" ]]
}

@test "post-clean: wsl-vpnkit service removed" {
  [[ ! -f /etc/systemd/system/wsl-vpnkit.service ]]
}

@test "post-clean: wsl-vpnkit distro preserved" {
  # clean-soft must NOT remove the wsl-vpnkit distro (shared across WSL distros)
  run bash -c "wsl.exe -l -q 2>/dev/null | tr -d '\0\r' | grep -qx 'wsl-vpnkit'"
  assert_success
}

@test "post-clean: validate reports FAIL for docker" {
  run validate_all
  assert_failure
  assert_output --partial "FAIL"
}
