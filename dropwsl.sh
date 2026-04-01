#!/usr/bin/env bash
# shellcheck shell=bash
set -Eeuo pipefail

# ==========================================
# dropwsl (Cloud-Native) -- Orchestrator
# Supported: Ubuntu 22.04+, Debian 12+
# Installs: systemd, Docker Engine + Compose v2 + BuildX,
# kubectl (apt repo), kind, helm, Azure CLI, GitHub CLI
# Optional: VS Code extensions (if `code` exists)
# Validation: validate (default runs install then validate)
# ==========================================

# readlink -f resolves symlinks; ensures the real path when run via symlink
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
VERSION_FILE="${SCRIPT_DIR}/VERSION"
DROPWSL_VERSION="unknown"
[[ -f "$VERSION_FILE" ]] && DROPWSL_VERSION="$(tr -d '\r' < "$VERSION_FILE")" || true

# ---- ERR trap: log failing command before set -e aborts ----
# Writes to stdout (fd 1), NOT stderr. PS 5.1 SilentlyContinue in install.ps1
# swallows ALL stderr from native commands (NativeCommandError), so errors on fd 2
# would be invisible to the user. stdout always flows through.
_on_err() {
  local exit_code=$?
  local cmd="$BASH_COMMAND"
  local src="${BASH_SOURCE[1]:-$0}"
  local line="${BASH_LINENO[0]:-?}"
  # Strip SCRIPT_DIR prefix for readability
  src="${src#"$SCRIPT_DIR"/}"
  echo -e "\n\033[31m[ERROR]\033[0m Command failed (exit $exit_code): $cmd"
  echo -e "        at ${src}:${line}"
  [[ -n "${LOG_FILE:-}" ]] && {
    echo "[ERROR] Command failed (exit $exit_code): $cmd" >> "$LOG_FILE"
    echo "        at ${src}:${line}" >> "$LOG_FILE"
  } || true
}
trap '_on_err' ERR

# ---- Load modules ----
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/validate.sh"
source "${SCRIPT_DIR}/lib/clean.sh"
for _f in "${SCRIPT_DIR}"/lib/core/*.sh; do [[ -f "$_f" ]] || continue; source "$_f"; done
for _f in "${SCRIPT_DIR}"/lib/project/*.sh; do [[ -f "$_f" ]] || continue; source "$_f"; done
unset _f

# ---- Load config (overrides defaults) ----
load_config "${SCRIPT_DIR}/config.yaml"

usage() {
  cat <<EOF
dropwsl v${DROPWSL_VERSION} -- Cloud-Native dev environment

Usage:
  dropwsl install                        # install everything + validate
  dropwsl validate                       # validate only (no install)
  dropwsl update                         # update everything (WSL + extensions + repo)
  dropwsl new svc python                 # create project + git + scaffold + open VS Code
  dropwsl new svc python --with src      # same, with src/ layout
  dropwsl scaffold python                # scaffold .devcontainer/ in current directory
  dropwsl layers                         # list available layers
  dropwsl config                         # show effective configuration
  dropwsl doctor                         # proactive environment diagnostics
  dropwsl uninstall                      # remove tools (preserves distro)

  Multi-service workspace:
  dropwsl new plat --service api python --with src,fastapi
  dropwsl new plat --service worker python --with src

Optional layers (--with):
  src            Reorganize to src/ layout (PEP 621)
  fastapi        Add FastAPI + Uvicorn with /health endpoint
  streamlit      Add Streamlit showcase app
  mypy           Add mypy (type checking) with strict mode
  uv             Replace pip with uv (10-100x faster installs)
  locust         Add locustfile.py for load testing
  postgres       Add PostgreSQL (compose service + asyncpg)
  redis          Add Redis (compose service + redis-py)
  testcontainers Add Testcontainers for integration tests
  compose        Add compose.yaml with app service
  gitleaks       Pre-commit hook to block commits with secrets
  trivy          Vulnerability scanner (CVEs) in VS Code
  mcp-github     GitHub MCP server (repos, issues, PRs via Copilot)
  mcp-docker     Docker MCP server (containers, images via Copilot)
  mcp-fetch      Fetch MCP server (HTTP requests via Copilot)
  mcp-git        Git MCP server (commits, branches, diffs via Copilot)
  semgrep        Multi-language SAST (static code analysis)
  agent-developer @developer agent (AI-Powered Dev: instructions + knowledge + hooks)

  Combine with comma or space: --with src,fastapi,uv  OR  --with src fastapi uv
  gitleaks and trivy are applied by default (see defaults in config.yaml)

Flags:
  -q, --quiet       Suppress verbose apt output (keeps script logs)
  -y, --yes         Skip interactive confirmations
  --no-defaults     Skip default layers (gitleaks, trivy)
  --service <name>  Create service inside multi-service workspace
  -h, --help        This message
  -v, --version     Show version

Logs:
  All runs are logged to ~/.local/state/dropwsl/logs/
  Auto-rotation: only the 5 most recent are kept.

EOF
}

uninstall_usage() {
  cat <<EOF
dropwsl uninstall -- remove tools or destroy the WSL distro

Usage:
  dropwsl uninstall                 # remove tools only (same as --tools)
  dropwsl uninstall --tools         # remove tools only (preserves distro)
  dropwsl uninstall --unregister    # destroy distro (Windows side only)
  dropwsl uninstall --purge         # destroy distro + uninstall WSL from Windows
  dropwsl uninstall --help          # show this message

Flags:
  --tools         Remove tools only and preserve the distro
  --full          Alias for --unregister
  --unregister    Destroy the WSL distro (must run from Windows)
  --remove-wsl    Alias for --purge
  --purge         Destroy distro and uninstall WSL from Windows
  -y, --yes       Skip interactive confirmations when removing tools
  -h, --help      This message

Notes:
  Inside WSL, dropwsl uninstall removes tools only.
  To unregister the distro or uninstall WSL itself, run dropwsl.cmd or uninstall.cmd from Windows.

EOF
}

# ---- Parse all arguments in a single pass ----
# Populates locals declared in main(): action, action_args, with_layers,
# service_name, _want_help, _want_version, _has_tools, _has_unregister,
# _has_purge.
# Also sets globals: QUIET, ASSUME_YES, NO_DEFAULTS.
_parse_args() {
  local arg collecting_args=false collecting_with=false collecting_service=false
  for arg in "$@"; do
    case "$arg" in
      --quiet|-q)     QUIET=true; collecting_with=false; collecting_service=false ;;
      --yes|-y)       ASSUME_YES=true; collecting_with=false; collecting_service=false ;;
      --no-defaults)  NO_DEFAULTS=true; collecting_with=false; collecting_service=false ;;
      --help|-h)      _want_help=true; collecting_with=false; collecting_service=false ;;
      --version|-v)   _want_version=true; collecting_with=false; collecting_service=false ;;
      --tools)        _has_tools=true; collecting_with=false; collecting_service=false ;;
      --full|--unregister)    _has_unregister=true; collecting_with=false; collecting_service=false ;;
      --remove-wsl|--purge)   _has_purge=true; collecting_with=false; collecting_service=false ;;
      --with)
        collecting_with=true; collecting_service=false; continue ;;
      --with=*)
        local _wval="${arg#--with=}"
        with_layers="${with_layers:+${with_layers},}${_wval}"; collecting_with=false ;;
      --service)
        collecting_service=true; collecting_with=false; continue ;;
      --service=*)
        service_name="${arg#--service=}"; collecting_with=false; collecting_service=false ;;
      --install|--validate|--update|--new|--scaffold|--clean|--clean-soft|--doctor|--config|--layers|--uninstall)
        action="${arg#--}"
        collecting_args=true; collecting_with=false; collecting_service=false ;;
      --*)
        warn "Unknown flag: $arg (ignored)"
        collecting_with=false; collecting_service=false ;;
      *)
        if $collecting_service; then
          service_name="$arg"; collecting_service=false
        elif $collecting_with; then
          arg="${arg#,}"; arg="${arg%,}"
          [[ -n "$arg" ]] && with_layers="${with_layers:+${with_layers},}${arg}"
        elif $collecting_args; then
          action_args+=("$arg")
        else
          action="$arg"; collecting_args=true
        fi ;;
    esac
  done
}

# ---- Dispatch to the correct action ----
# Actions that don't need WSL/sudo are handled first.
# If no action matches (install or empty), returns to caller for _run_install.
_route_action() {
  case "$action" in
    layers|list-layers)
      update_self false; list_layers; exit 0 ;;
    config)
      show_config; exit 0 ;;
    scaffold)
      update_self false; scaffold_devcontainer "${action_args[0]:-}"; exit 0 ;;
    new)
      update_self false
      new_project "${action_args[0]:-}" "${action_args[1]:-}" "$with_layers" "$service_name"
      exit 0 ;;
    update)
      update_self true; exit 0 ;;
  esac

  # Remaining actions require WSL + sudo + supported distro
  ensure_wsl
  ensure_sudo
  ensure_supported_distro

  case "$action" in
    validate)   validate_all; exit 0 ;;
    doctor)     run_doctor; exit $? ;;
    clean)      clean_all; exit 0 ;;
    clean-soft) clean_soft; exit 0 ;;
    uninstall)
      if $_has_unregister || $_has_purge; then
        die_hint "uninstall --unregister must be run from Windows" \
          "This command needs to run on the Windows side to unregister the WSL distro" \
          "In PowerShell (Admin): uninstall.cmd --unregister;In PowerShell (Admin): dropwsl.cmd uninstall --unregister" \
          "dropwsl.cmd uninstall --unregister"
      fi
      clean_soft; exit 0 ;;
    install) return ;;
    "")     usage; exit 0 ;;
    *) warn "Unknown command: $action"; usage; exit 1 ;;
  esac
}

# ---- Full installation flow ----
_run_install() {
  log "dropwsl v${DROPWSL_VERSION} -- starting installation"

  enable_systemd_if_needed
  apt_base

  # Install tools enabled in config.yaml
  local tool
  for tool in "${ENABLED_CORE[@]}"; do
    if declare -F "install_${tool}" >/dev/null 2>&1; then
      "install_${tool}"
    else
      warn "Function install_${tool} not found -- skipping"
    fi
  done

  install_vscode_extensions
  configure_gcm
  configure_git_defaults
  clone_dropwsl_repo

  validate_all
  show_first_run_banner
  _activate_docker_group
}

# ---- Activate docker group if needed (must be last instruction) ----
# newgrp replaces the current process; only safe in interactive terminals.
_activate_docker_group() {
  if id -nG "$USER" 2>/dev/null | grep -qw docker \
     && ! id -nG 2>/dev/null | grep -qw docker; then
    if [[ -t 0 ]] && [[ -z "${DROPWSL_BATCH:-}" ]]; then
      log "Activating docker group in this session (newgrp docker)..."
      exec newgrp docker
    else
      warn "Docker group added but not active in this session. Close and reopen the terminal, or run: newgrp docker"
    fi
  fi
}

main() {
  local action="" service_name="" with_layers=""
  local action_args=()
  local _want_help=false _want_version=false
  local _has_tools=false
  local _has_unregister=false _has_purge=false

  _parse_args "$@"

  if $_want_help; then
    case "$action" in
      uninstall) uninstall_usage ;;
      *) usage ;;
    esac
    exit 0
  fi
  if $_want_version; then echo "dropwsl v${DROPWSL_VERSION}"; exit 0; fi

  # Show banner when running directly in WSL (not via install.ps1/dropwsl.ps1)
  if [[ -z "${DROPWSL_BATCH:-}" ]]; then
    show_banner
  fi

  setup_logging
  _route_action
  _run_install
}

# Only run main when executed directly; skip when sourced (e.g., from tests).
# Uses if/fi instead of && to avoid exit 1 under set -e when condition is false.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then main "$@"; fi
