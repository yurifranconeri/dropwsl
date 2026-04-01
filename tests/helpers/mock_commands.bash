#!/usr/bin/env bash
# tests/helpers/mock_commands.bash — Stubs for system commands (offline tests)
# Usage: load '../helpers/mock_commands'

# Mock has_cmd: returns true for commands in MOCK_AVAILABLE_CMDS
MOCK_AVAILABLE_CMDS=()
mock_has_cmd() {
  local cmd="$1"
  for c in "${MOCK_AVAILABLE_CMDS[@]}"; do
    [[ "$c" == "$cmd" ]] && return 0
  done
  return 1
}

# Mock sudo: executes without sudo
mock_sudo() { "$@"; }

# Mock git: records calls
MOCK_GIT_CALLS=()
mock_git() { MOCK_GIT_CALLS+=("$*"); }

# Mock run_quiet: executes directly
mock_run_quiet() { "$@"; }

# Mock code (VS Code): no-op
mock_code() { return 0; }

# Mock cmd.exe: no-op
mock_cmd_exe() { return 0; }

# Activate all mocks (redefine functions)
activate_mocks() {
  has_cmd()   { mock_has_cmd "$@"; }
  sudo()      { mock_sudo "$@"; }
  git()       { mock_git "$@"; }
  run_quiet() { mock_run_quiet "$@"; }
  code()      { mock_code "$@"; }
  cmd.exe()   { mock_cmd_exe "$@"; }
  export -f has_cmd sudo git run_quiet code
}
