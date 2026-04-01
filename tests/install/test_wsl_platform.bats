#!/usr/bin/env bats
# tests/install/test_wsl_platform.bats -- Validates WSL platform is functional
#
# REQUIREMENTS:
#   - Runs inside a WSL distro (Ubuntu 22.04+ or Debian 12+)
#   - dropwsl must have been installed (install.cmd completed)
#
# These tests verify the Windows-side provisioning that install.ps1 performs:
# WSL platform, distro registration, .wslconfig, and user configuration.

setup() {
  load '../helpers/test_helper'
  _common_setup
}

teardown() {
  _common_teardown
}

# ---- WSL environment ----

@test "wsl: running inside WSL" {
  [[ -n "${WSL_DISTRO_NAME:-}" ]]
}

@test "wsl: /etc/os-release exists" {
  [[ -f /etc/os-release ]]
}

@test "wsl: distro is Ubuntu or Debian" {
  source /etc/os-release
  [[ "$ID" == "ubuntu" || "$ID" == "debian" ]]
}

@test "wsl: distro version meets minimum" {
  source /etc/os-release
  if [[ "$ID" == "ubuntu" ]]; then
    # Ubuntu 22.04+
    local major="${VERSION_ID%%.*}"
    [[ "$major" -ge 22 ]]
  elif [[ "$ID" == "debian" ]]; then
    # Debian 12+
    local major="${VERSION_ID%%.*}"
    [[ "$major" -ge 12 ]]
  fi
}

@test "wsl: systemd is PID 1" {
  local pid1
  pid1="$(ps -p 1 -o comm= 2>/dev/null || true)"
  [[ "$pid1" == "systemd" || "$pid1" == "init" ]]
}

# ---- User provisioning ----

@test "user: current user is not root" {
  [[ "$(id -u)" -ne 0 ]]
}

@test "user: current user has home directory" {
  [[ -d "$HOME" ]]
}

@test "user: current user is in sudo group" {
  run id -nG
  assert_output --partial "sudo"
}

@test "user: sudoers.d file exists for current user" {
  local username
  username="$(id -un)"
  [[ -f "/etc/sudoers.d/${username}" ]]
}

@test "user: default user configured in /etc/wsl.conf" {
  local username
  username="$(id -un)"
  run grep -F "default=${username}" /etc/wsl.conf
  assert_success
}

# ---- .wslconfig (read from Windows side) ----

@test "wslconfig: file exists" {
  local wslconfig
  wslconfig="$(wslpath "$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')")/.wslconfig"
  [[ -f "$wslconfig" ]]
}

@test "wslconfig: contains [wsl2] section" {
  local wslconfig
  wslconfig="$(wslpath "$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')")/.wslconfig"
  run grep -F '[wsl2]' "$wslconfig"
  assert_success
}

@test "wslconfig: networkingMode is set" {
  local wslconfig
  wslconfig="$(wslpath "$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')")/.wslconfig"
  run grep -E '^networkingMode\s*=' "$wslconfig"
  assert_success
}

@test "wslconfig: processors is set" {
  local wslconfig
  wslconfig="$(wslpath "$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')")/.wslconfig"
  run grep -E '^processors\s*=' "$wslconfig"
  assert_success
}

@test "wslconfig: memory is set" {
  local wslconfig
  wslconfig="$(wslpath "$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')")/.wslconfig"
  run grep -E '^memory\s*=' "$wslconfig"
  assert_success
}


