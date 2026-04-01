#!/usr/bin/env bash
# tests/run-tests.sh — Entry point for test execution
# Usage: ./tests/run-tests.sh <level> [bats options]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BATS="${REPO_ROOT}/tests/bats/bats-core/bin/bats"

# Cores
RED='\033[31m'; GREEN='\033[32m'; CYAN='\033[36m'; RESET='\033[0m'

# Ctrl+C mata o process group inteiro (bats + docker children)
trap 'trap - INT TERM; echo -e "\n${RED}Interrupted${RESET}"; kill -TERM 0 2>/dev/null; wait; exit 130' INT TERM

usage() {
  cat <<EOF
Usage: $(basename "$0") <level> [bats options]

Levels:
  unit             Unit tests — pure functions, parser, helpers (~5s)
  integration      Integration tests — file generation, layers (~10s)
  smoke            Smoke tests — requires WSL with tools installed (~30s)
  e2e              E2E — build Docker real, compose, HTTP requests (~10min)
  docker           Alias for e2e
  uninstall        Uninstall — DESTRUCTIVE: clean-soft, unregister, purge
  install          Install — validates full provisioning (WSL + tools + config)
  all              Unit + Integration (runs on any machine)
  pyramid          Full pyramid: unit → integration → smoke → e2e (stops on 1st FAIL)
  full             All at once (unit + integration + smoke + e2e)
  pester           PowerShell tests via Pester (Windows only)

Bats options (passed to bats-core):
  --filter <regex>     Filter tests by name
  --filter-tags <tag>  Filter by tag
  --jobs <n>           Parallelism
  --tap                Output in TAP format
  --verbose-run        Show each command executed
  --no-tempdir-cleanup Preserve temp dirs for debug
EOF
  exit 1
}

BATS_VERSION="v1.11.1"
ASSERT_VERSION="v2.1.0"
SUPPORT_VERSION="v0.3.0"

install_bats() {
  local bats_dir="${REPO_ROOT}/tests/bats"
  echo -e "${CYAN}==> Installing bats-core (first run)...${RESET}"
  mkdir -p "$bats_dir"
  git clone --depth 1 --branch "$BATS_VERSION" https://github.com/bats-core/bats-core.git "${bats_dir}/bats-core" 2>&1
  git clone --depth 1 --branch "$ASSERT_VERSION" https://github.com/bats-core/bats-assert.git "${bats_dir}/bats-assert" 2>&1
  git clone --depth 1 --branch "$SUPPORT_VERSION" https://github.com/bats-core/bats-support.git "${bats_dir}/bats-support" 2>&1
  if [[ ! -x "$BATS" ]]; then
    echo -e "${RED}[ERROR]${RESET} Failed to install bats-core."
    exit 1
  fi
  echo -e "${GREEN}[OK]${RESET} bats-core ${BATS_VERSION} installed in tests/bats/"
}

check_bats() {
  if [[ ! -x "$BATS" ]]; then
    install_bats
  fi
}

run_bats() {
  local label="$1"; shift
  local -a dirs=()
  while [[ $# -gt 0 ]] && [[ -d "$1" ]]; do
    dirs+=("$1"); shift
  done
  echo -e "${CYAN}==> ${label}${RESET}"
  "$BATS" --recursive "${dirs[@]}" "$@"
}

run_pester() {
  echo -e "${CYAN}==> Pester (PowerShell)${RESET}"
  local pester_script="${REPO_ROOT}/tests/run-pester.ps1"
  if command -v pwsh >/dev/null 2>&1; then
    pwsh -NoProfile -ExecutionPolicy Bypass -File "$pester_script"
  elif command -v powershell.exe >/dev/null 2>&1; then
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$pester_script"
  else
    echo -e "${RED}[ERROR]${RESET} PowerShell not found. Install pwsh or run on Windows."
    exit 1
  fi
}

[[ $# -lt 1 ]] && usage
level="$1"; shift

case "$level" in
  unit)
    check_bats
    run_bats "Unit Tests" "${REPO_ROOT}/tests/unit/" "$@"
    ;;
  integration)
    check_bats
    run_bats "Integration Tests" "${REPO_ROOT}/tests/integration/" "$@"
    ;;
  smoke)
    check_bats
    run_bats "Smoke Tests" "${REPO_ROOT}/tests/smoke/" "$@"
    ;;
  all)
    check_bats
    run_bats "Unit + Integration" "${REPO_ROOT}/tests/unit/" "${REPO_ROOT}/tests/integration/" "$@"
    ;;
  pyramid)
    check_bats
    run_bats "Unit Tests"        "${REPO_ROOT}/tests/unit/"        "$@"
    run_bats "Integration Tests" "${REPO_ROOT}/tests/integration/" "$@"
    run_bats "Smoke Tests"       "${REPO_ROOT}/tests/smoke/"       "$@"
    run_bats "E2E Tests"         "${REPO_ROOT}/tests/e2e/"         "$@"
    echo -e "${GREEN}==> Full pyramid complete ✔${RESET}"
    ;;
  full)
    check_bats
    run_bats "Full Suite" \
      "${REPO_ROOT}/tests/unit/" \
      "${REPO_ROOT}/tests/integration/" \
      "${REPO_ROOT}/tests/smoke/" \
      "${REPO_ROOT}/tests/e2e/" \
      "$@"
    ;;
  e2e|docker)
    check_bats
    run_bats "E2E Tests (Docker runtime)" "${REPO_ROOT}/tests/e2e/" "$@"
    ;;
  uninstall)
    check_bats
    run_bats "Uninstall Tests (DESTRUCTIVE)" "${REPO_ROOT}/tests/uninstall/" "$@"
    ;;
  install)
    check_bats
    run_bats "Install Tests (requires provisioned WSL)" "${REPO_ROOT}/tests/install/" "$@"
    ;;
  pester)
    run_pester
    ;;
  *)
    echo -e "${RED}[ERROR]${RESET} Unknown level: '$level'"
    usage
    ;;
esac
