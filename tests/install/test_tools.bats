#!/usr/bin/env bats
# tests/install/test_tools.bats -- Validates all core tools installed by dropwsl.sh
#
# REQUIREMENTS:
#   - Runs inside WSL with dropwsl fully provisioned
#   - install.cmd must have completed successfully
#
# These tests verify the bash-side provisioning: Docker, kubectl, kind, helm,
# Azure CLI, GitHub CLI, Git + GCM, and the dropwsl symlink.

setup() {
  load '../helpers/test_helper'
  _common_setup
}

teardown() {
  _common_teardown
}

# ---- Docker ----

@test "docker: CLI is installed" {
  run command -v docker
  assert_success
}

@test "docker: daemon is running" {
  run docker info
  assert_success
}

@test "docker: current user can run without sudo" {
  run docker ps
  assert_success
}

@test "docker: compose plugin is available" {
  run docker compose version
  assert_success
}

@test "docker: daemon.json has log rotation configured" {
  [[ -f /etc/docker/daemon.json ]]
  run grep -F 'max-size' /etc/docker/daemon.json
  assert_success
}

@test "docker: daemon.json has default-address-pools configured" {
  [[ -f /etc/docker/daemon.json ]]
  run grep -F 'default-address-pools' /etc/docker/daemon.json
  assert_success
}

# ---- kubectl ----

@test "kubectl: is installed" {
  run command -v kubectl
  assert_success
}

@test "kubectl: returns version" {
  run kubectl version --client --output=yaml
  assert_success
}

# ---- kind ----

@test "kind: is installed" {
  run command -v kind
  assert_success
}

@test "kind: returns version" {
  run kind version
  assert_success
}

# ---- helm ----

@test "helm: is installed" {
  run command -v helm
  assert_success
}

@test "helm: returns version" {
  run helm version --short
  assert_success
}

# ---- Azure CLI ----

@test "azure-cli: is installed" {
  if [[ "$(cfg_get 'tools.azure-cli.enabled' 'true')" != "true" ]]; then
    skip "azure-cli disabled in config"
  fi
  run command -v az
  assert_success
}

@test "azure-cli: returns version" {
  if [[ "$(cfg_get 'tools.azure-cli.enabled' 'true')" != "true" ]]; then
    skip "azure-cli disabled in config"
  fi
  run az version --output table
  assert_success
}

# ---- wsl-vpnkit ----

@test "wsl-vpnkit: distro is imported" {
  if [[ "$(cfg_get 'core.wsl-vpnkit.enabled' 'true')" != "true" ]]; then
    skip "wsl-vpnkit disabled in config"
  fi
  run bash -c "wsl.exe -l -q 2>/dev/null | tr -d '\0\r' | grep -qx 'wsl-vpnkit'"
  assert_success
}

@test "wsl-vpnkit: systemd service is active" {
  if [[ "$(cfg_get 'core.wsl-vpnkit.enabled' 'true')" != "true" ]]; then
    skip "wsl-vpnkit disabled in config"
  fi
  run systemctl is-active wsl-vpnkit
  assert_success
}

@test "wsl-vpnkit: service file has Before=docker.service" {
  if [[ "$(cfg_get 'core.wsl-vpnkit.enabled' 'true')" != "true" ]]; then
    skip "wsl-vpnkit disabled in config"
  fi
  [[ -f /etc/systemd/system/wsl-vpnkit.service ]]
  run grep -F 'Before=docker.service' /etc/systemd/system/wsl-vpnkit.service
  assert_success
}

# ---- GitHub CLI ----

@test "github-cli: is installed" {
  if [[ "$(cfg_get 'tools.github-cli.enabled' 'true')" != "true" ]]; then
    skip "github-cli disabled in config"
  fi
  run command -v gh
  assert_success
}

@test "github-cli: returns version" {
  if [[ "$(cfg_get 'tools.github-cli.enabled' 'true')" != "true" ]]; then
    skip "github-cli disabled in config"
  fi
  run gh version
  assert_success
}

# ---- .NET SDK ----

@test "dotnet: is installed" {
  if [[ "$(cfg_get 'core.dotnet.enabled' 'false')" != "true" ]]; then
    skip "dotnet disabled in config"
  fi
  run command -v dotnet
  assert_success
}

@test "dotnet: returns version" {
  if [[ "$(cfg_get 'core.dotnet.enabled' 'false')" != "true" ]]; then
    skip "dotnet disabled in config"
  fi
  run dotnet --version
  assert_success
}

# ---- PAC CLI ----

@test "pac-cli: is installed" {
  if [[ "$(cfg_get 'core.pac-cli.enabled' 'false')" != "true" ]]; then
    skip "pac-cli disabled in config"
  fi
  run command -v pac
  assert_success
}

@test "pac-cli: returns version" {
  if [[ "$(cfg_get 'core.pac-cli.enabled' 'false')" != "true" ]]; then
    skip "pac-cli disabled in config"
  fi
  run pac --version
  assert_success
}

# ---- Node.js ----

@test "nodejs: is installed" {
  if [[ "$(cfg_get 'core.nodejs.enabled' 'false')" != "true" ]]; then
    skip "nodejs disabled in config"
  fi
  run command -v node
  assert_success
}

@test "nodejs: returns version" {
  if [[ "$(cfg_get 'core.nodejs.enabled' 'false')" != "true" ]]; then
    skip "nodejs disabled in config"
  fi
  run node --version
  assert_success
}

# ---- Bun ----

@test "bun: is installed" {
  if [[ "$(cfg_get 'core.bun.enabled' 'false')" != "true" ]]; then
    skip "bun disabled in config"
  fi
  run command -v bun
  assert_success
}

@test "bun: returns version" {
  if [[ "$(cfg_get 'core.bun.enabled' 'false')" != "true" ]]; then
    skip "bun disabled in config"
  fi
  run bun --version
  assert_success
}

# ---- DNS utils ----

@test "dig: is installed" {
  run command -v dig
  assert_success
}

@test "host: is installed" {
  run command -v host
  assert_success
}

# ---- Git ----

@test "git: is installed" {
  run command -v git
  assert_success
}

@test "git: default branch is configured" {
  run git config --global init.defaultBranch
  assert_success
  assert_output "main"
}

@test "git: credential helper is configured (GCM)" {
  run git config --global credential.helper
  assert_success
  assert_output --partial "manager"
}

# ---- dropwsl symlink ----

@test "dropwsl: symlink exists" {
  [[ -L "${HOME}/.local/bin/dropwsl" ]] || [[ -x "${HOME}/.local/bin/dropwsl" ]]
}

@test "dropwsl: is in PATH" {
  run command -v dropwsl
  assert_success
}

@test "dropwsl: --version works" {
  run dropwsl --version
  assert_success
  assert_output --partial "dropwsl"
}

@test "dropwsl: --help works" {
  run dropwsl --help
  assert_success
  assert_output --partial "Usage"
}
