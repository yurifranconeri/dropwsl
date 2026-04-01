#!/usr/bin/env bash
# shellcheck shell=bash
# lib/common.sh -- Shared helpers, logging, config parser, base validations.
# Sourced by dropwsl.sh; never executed directly.

# ---- Guard contra double-source ----
[[ -n "${_COMMON_SH_LOADED:-}" ]] && return 0
_COMMON_SH_LOADED=1

# ---- Global variables (defaults; overridden by load_config) ----
# REPO_URL: canonical value lives in config.yaml (repo.url).
# Env var override honored; no hardcoded fallback (single source of truth).
REPO_URL="${REPO_URL:-}"
INSTALL_DIR="${INSTALL_DIR:-${HOME}/.local/share/dropwsl}"
BIN_DIR="${HOME}/.local/bin"
BIN_LINK="${BIN_DIR}/dropwsl"
PROJECTS_DIR="${PROJECTS_DIR:-${HOME}/projects}"

QUIET=false
ASSUME_YES=false
export DEBIAN_FRONTEND=noninteractive

# Distros and minimum versions (defaults; overridden by config)
SUPPORTED_DISTROS=(ubuntu debian)
MIN_UBUNTU="22.04"
MIN_DEBIAN="12"

# Tool versions (defaults; overridden by config)
WSL_VPNKIT_VERSION="v0.4.1"
KUBECTL_VERSION="1.34"
KIND_VERSION="v0.27.0"
HELM_VERSION="v3.17.3"
GITLEAKS_VERSION="v8.21.2"

# Docker daemon config (defaults; overridden by config)
DOCKER_MTU=1400
DOCKER_LOG_MAX_SIZE="10m"
DOCKER_LOG_MAX_FILE=3

# Enabled core tools (populated by load_config)
ENABLED_CORE=()

# Default layers applied to every --new (populated by load_config)
DEFAULT_LAYERS=()

# Flag --no-defaults (desabilita layers default)
NO_DEFAULTS=false

# VS Code extensions (default; overridden by config)
VSCODE_EXTENSIONS=(
  ms-vscode-remote.remote-wsl
  ms-vscode-remote.remote-containers
  ms-azuretools.vscode-docker
)

# Git defaults (default; overridden by config)
# NOTE: keep in sync with config.yaml git.defaults
declare -A GIT_DEFAULTS=(
  [init.defaultBranch]="main"
  [core.autocrlf]="input"
  [push.autoSetupRemote]="true"
  [pull.ff]="only"
  [fetch.prune]="true"
  [diff.colorMoved]="zebra"
  [merge.conflictstyle]="zdiff3"
  [rerere.enabled]="true"
  [rebase.autoStash]="true"
)

# ---- Log file ----
# LOG_DIR is OUTSIDE INSTALL_DIR so it's not destroyed by clone_dropwsl_repo
LOG_DIR="${HOME}/.local/state/dropwsl/logs"
LOG_FILE=""

# ===========================================================================
# Temporary file pool with automatic cleanup via trap EXIT
# ===========================================================================
TMPFILES=()
TMPDIRS=()
make_temp() { local f; f="$(mktemp)"; TMPFILES+=("$f"); echo "$f"; }
make_temp_dir() { local d; d="$(mktemp -d)"; TMPDIRS+=("$d"); echo "$d"; }
cleanup_tmpfiles() {
  [[ ${#TMPFILES[@]} -gt 0 ]] && rm -f "${TMPFILES[@]}" 2>/dev/null || true
  [[ ${#TMPDIRS[@]} -gt 0 ]] && rm -rf "${TMPDIRS[@]}" 2>/dev/null || true
}
# Additive trap -- preserves existing traps
_prev_exit_trap="$(trap -p EXIT | sed "s/^trap -- '\(.*\)' EXIT$/\1/")"
trap "${_prev_exit_trap:+$_prev_exit_trap; }cleanup_tmpfiles" EXIT

# ===========================================================================
# Banner -- ASCII art shown on every user-facing invocation.
# Subtitle is optional (e.g. "Installer", "Uninstaller").
# ===========================================================================
show_banner() {
  local subtitle="${1:-}"
  echo ""
  echo -e "\033[36m       _                             _\033[0m"
  echo -e "\033[36m    __| |_ __ ___  _ ____      __ __| |\033[0m"
  echo -e "\033[36m   / _\` | '__/ _ \\| '_ \\ \\ /\\ / / __| |\033[0m"
  echo -e "\033[36m  | (_| | | | (_) | |_) \\ V  V /\\__ \\ |___\033[0m"
  echo -e "\033[36m   \\__,_|_|  \\___/| .__/ \\_/\\_/ |___/_____|\033[0m"
  echo -e "\033[36m                  |_|\033[0m"
  echo ""
  if [[ -n "$subtitle" ]]; then
    echo -e "\033[32m  dropwsl v${DROPWSL_VERSION} -- ${subtitle}\033[0m"
  else
    echo -e "\033[32m  dropwsl v${DROPWSL_VERSION}\033[0m"
  fi
  echo ""
}

# ===========================================================================
# Logging -- writes to both terminal AND log file (when active).
# IMPORTANT: || true prevents set -e from killing the script when LOG_FILE is empty
# ===========================================================================
log() {
  echo -e "\n\033[36m==>\033[0m $*"
  [[ -n "$LOG_FILE" ]] && echo "==> $*" >> "$LOG_FILE" || true
}
warn() {
  echo -e "\n\033[33m[WARN]\033[0m $*"
  [[ -n "$LOG_FILE" ]] && echo "[WARN] $*" >> "$LOG_FILE" || true
}
die() {
  echo -e "\n\033[31m[ERROR]\033[0m $*"
  [[ -n "$LOG_FILE" ]] && echo "[ERROR] $*" >> "$LOG_FILE" || true
  exit 1
}

# die_hint -- die() with probable causes, numbered solutions and manual verification.
# Usage: die_hint "message" "cause1;cause2" "solution1;solution2" ["manual command"]
# The 4th parameter is optional. Uses ; as separator for multiple items.
die_hint() {
  local msg="$1" causes="$2" solutions="$3" manual="${4:-}"

  echo -e "\n\033[31m[ERROR]\033[0m $msg"
  [[ -n "$LOG_FILE" ]] && echo "[ERROR] $msg" >> "$LOG_FILE" || true

  echo
  echo -e "  \033[33mProbable causes:\033[0m"
  local IFS=';'
  local item
  set -f
  for item in $causes; do
    item="$(echo "$item" | sed 's/^[[:space:]]*//')"
    [[ -n "$item" ]] && echo "    - $item"
  done

  echo
  echo -e "  \033[32mSolutions:\033[0m"
  local i=1
  for item in $solutions; do
    item="$(echo "$item" | sed 's/^[[:space:]]*//')"
    [[ -n "$item" ]] && { echo "    $i. $item"; ((i++)); }
  done
  set +f

  if [[ -n "$manual" ]]; then
    echo
    echo -e "  \033[36mManual verification:\033[0m"
    echo "    \$ $manual"
  fi

  if [[ -n "$LOG_FILE" ]]; then
    echo "" >> "$LOG_FILE"
    echo "  Causes: $causes" >> "$LOG_FILE"
    echo "  Solutions: $solutions" >> "$LOG_FILE"
    [[ -n "$manual" ]] && echo "  Verification: $manual" >> "$LOG_FILE"
  fi

  echo
  exit 1
}

# Runs command suppressing stdout+stderr when --quiet.
run_quiet() {
  if [[ "$QUIET" == true ]]; then
    if [[ -n "$LOG_FILE" ]]; then
      "$@" >> "$LOG_FILE" 2>&1
    else
      "$@" > /dev/null 2>&1
    fi
  else
    if [[ -n "$LOG_FILE" ]]; then
      "$@" 2>&1 | tee -a "$LOG_FILE"
    else
      "$@"
    fi
  fi
}

# ===========================================================================
# setup_logging -- Creates log file with timestamp and rotation.
# Rotation: keeps only the 5 most recent logs.
# ===========================================================================
setup_logging() {
  mkdir -p "$LOG_DIR"
  LOG_FILE="${LOG_DIR}/dropwsl-$(date +%Y%m%d_%H%M%S).log"

  local -a old_logs
  mapfile -t old_logs < <(ls -1t "$LOG_DIR"/dropwsl-*.log 2>/dev/null | tail -n +6)
  if (( ${#old_logs[@]} > 0 )); then
    rm -f "${old_logs[@]}"
  fi

  log "Log saved to: $LOG_FILE"
}

# ===========================================================================
# curl_retry -- Wrapper with up to 3 retries and backoff (1s, 2s, 3s).
# ===========================================================================
curl_retry() {
  local attempt=1
  local max=3
  while (( attempt <= max )); do
    if curl --connect-timeout 15 --max-time 120 "$@"; then
      return 0
    fi
    if (( attempt < max )); then
      warn "curl failed (attempt $attempt/$max), retrying in ${attempt}s..."
      sleep "$attempt"
    else
      warn "curl failed (attempt $attempt/$max)."
    fi
    ((attempt++))
  done
  die_hint "curl failed after $max attempts." \
    "No internet connection;DNS not resolving;Corporate proxy blocking" \
    "Check your network connection;If using proxy, configure http_proxy/https_proxy;Try again later" \
    "curl -v $*"
}

# ===========================================================================
# Utilidades
# ===========================================================================
is_wsl() { grep -qi microsoft /proc/version 2>/dev/null; }
has_cmd() { command -v "$1" >/dev/null 2>&1; }

# Compares semantic versions. Returns 0 if $1 >= $2.
version_gte() { local a="${1#v}" b="${2#v}"; local oldest; oldest="$(printf '%s\n' "$b" "$a" | sort -V | head -n1)" || true; [[ "$oldest" == "$b" ]]; }

# Locates the templates directory, prioritizing SCRIPT_DIR (local execution)
# and falling back to INSTALL_DIR (cloned repo).
find_templates_dir() {
  if [[ -d "${SCRIPT_DIR}/templates/devcontainer" ]]; then
    echo "${SCRIPT_DIR}/templates/devcontainer"
  elif [[ -d "${INSTALL_DIR}/templates/devcontainer" ]]; then
    echo "${INSTALL_DIR}/templates/devcontainer"
  else
    die "Templates not found. Run: ./dropwsl.sh --install to clone the repository."
  fi
}

# Locates templates directory for a layer, given scope and name.
# Searches: SCRIPT_DIR/templates/layers/<scope>/<layer>/
# Fallback: INSTALL_DIR/templates/layers/<scope>/<layer>/
# Usage: local tpl_dir; tpl_dir="$(find_layer_templates_dir "python" "fastapi")"
find_layer_templates_dir() {
  local scope="$1" layer="$2"
  local rel="templates/layers/${scope}/${layer}"
  if [[ -d "${SCRIPT_DIR}/${rel}" ]]; then
    echo "${SCRIPT_DIR}/${rel}"
  elif [[ -d "${INSTALL_DIR}/${rel}" ]]; then
    echo "${INSTALL_DIR}/${rel}"
  else
    die "Templates for layer '${layer}' not found at ${rel}"
  fi
}

# Escapes a string for safe use in sed substitution (with | delimiter).
# Handles backslash (\\), ampersand (&) and pipe (|).
# Usage: local safe; safe="$(_sed_escape "$var")"
_sed_escape() {
  local s="${1//\\/\\\\}"
  s="${s//&/\\&}"
  s="${s//|/\\|}"
  printf '%s' "$s"
}

# Converts a project name to a Python package name (hyphens/dots → underscores).
# Ensures the result is a valid importable identifier when the name starts with
# a digit.
# Usage: local pkg; pkg="$(_to_package_name "$name")"
_to_package_name() {
  local n="${1//-/_}"
  n="${n//./_}"
  if [[ "$n" =~ ^[0-9] ]]; then
    n="_${n}"
  fi
  printf '%s' "$n"
}

# Detects Python project layout by probing the filesystem.
# Sets globals: _HAS_SRC, _PKG_BASE, _HAS_API_FRAMEWORK, _HAS_COMPOSE,
# _HAS_LOCAL_INFRA.
# Usage: _detect_python_layout "$project_path" "$package_name"
_detect_python_layout() {
  local project_path="$1"
  local package_name="$2"
  local env_example="${project_path}/.env.example"

  _HAS_SRC=false
  _PKG_BASE="$project_path"
  if [[ -d "${project_path}/src/${package_name}" ]]; then
    _HAS_SRC=true
    _PKG_BASE="${project_path}/src/${package_name}"
  fi

  _HAS_API_FRAMEWORK=false
  if [[ -f "${_PKG_BASE}/main.py" ]] && grep -q 'app = FastAPI' "${_PKG_BASE}/main.py" 2>/dev/null; then
    _HAS_API_FRAMEWORK=true
  fi

  _HAS_COMPOSE=false
  if [[ -f "${project_path}/compose.yaml" ]]; then
    _HAS_COMPOSE=true
  fi

  _HAS_LOCAL_INFRA=false
  if [[ -f "$env_example" ]] && grep -Fxq '# -- dropwsl:local-infra --' "$env_example"; then
    _HAS_LOCAL_INFRA=true
  fi
}

# ===========================================================================
# render_template -- Copies template to destination, replacing {{PLACEHOLDERS}}.
# Usage: render_template "$src" "$dest" "VAR1=value1" "VAR2=value2"
# Creates intermediate directories automatically.
# ===========================================================================
render_template() {
  local src="$1" dest="$2"
  shift 2

  [[ -f "$src" ]] || { die "render_template: template not found: $src"; return 1; }

  mkdir -p "$(dirname "$dest")"
  cp -- "$src" "$dest"
  sed -i 's/\r$//' "$dest"

  local kv
  for kv in "$@"; do
    local key="${kv%%=*}"
    local val="${kv#*=}"
    local sed_safe; sed_safe="$(_sed_escape "$val")"
    sed -i "s|{{${key}}}|${sed_safe}|g" "$dest"
  done
}

# ===========================================================================
# inject_fragment -- Appends content from a fragment to a destination with dedup.
# Guard: if the first non-empty line of the fragment already exists in dest -> skip.
# Replaces {{PLACEHOLDERS}} before injecting.
# Usage: inject_fragment "$src" "$dest" ["VAR1=value1" ...]
# ===========================================================================
inject_fragment() {
  local src="$1" dest="$2"
  shift 2

  [[ -f "$src" ]] || { die "inject_fragment: fragment not found: $src"; return 1; }
  [[ -f "$dest" ]] || return 0

  # Dedup: first non-empty line of fragment as guard (exact line match)
  local guard
  guard="$(grep -m1 '[^[:space:]]' "$src")" || true
  if [[ -n "$guard" ]] && grep -Fxq "$guard" "$dest"; then
    return 0
  fi

  local tmp; tmp="$(make_temp)"
  cp -- "$src" "$tmp"
  sed -i 's/\r$//' "$tmp"

  local kv
  for kv in "$@"; do
    local key="${kv%%=*}"
    local val="${kv#*=}"
    local sed_safe; sed_safe="$(_sed_escape "$val")"
    sed -i "s|{{${key}}}|${sed_safe}|g" "$tmp"
  done

  cat "$tmp" >> "$dest"
}

# ===========================================================================
# inject_fragment_at -- Inserts content from a fragment AFTER a named marker.
# Marker format in dest: "# -- dropwsl:<section> --" (any comment style).
# If the marker is not found, falls back to append (like inject_fragment).
# Guard: same dedup as inject_fragment (first non-empty line).
# Replaces {{PLACEHOLDERS}} before injecting.
# Usage: inject_fragment_at "$src" "$dest" "section" ["VAR1=value1" ...]
# ===========================================================================
inject_fragment_at() {
  local src="$1" dest="$2" section="$3"
  shift 3

  [[ -f "$src" ]] || { die "inject_fragment_at: fragment not found: $src"; return 1; }
  [[ -f "$dest" ]] || return 0

  # Dedup: first non-empty line of fragment as guard (exact line match)
  local guard
  guard="$(grep -m1 '[^[:space:]]' "$src")" || true
  if [[ -n "$guard" ]] && grep -Fxq "$guard" "$dest"; then
    return 0
  fi

  local tmp; tmp="$(make_temp)"
  cp -- "$src" "$tmp"
  sed -i 's/\r$//' "$tmp"

  local kv
  for kv in "$@"; do
    local key="${kv%%=*}"
    local val="${kv#*=}"
    local sed_safe; sed_safe="$(_sed_escape "$val")"
    sed -i "s|{{${key}}}|${sed_safe}|g" "$tmp"
  done

  local marker="# -- dropwsl:${section} --"
  if grep -Fq "$marker" "$dest"; then
    sed -i "/${marker}/r ${tmp}" "$dest"
  else
    cat "$tmp" >> "$dest"
  fi
}

# ===========================================================================
# inject_mcp_server -- Creates/updates .vscode/mcp.json with an MCP server.
# Usage: inject_mcp_server "$project_path" "server-name" "server_json_block"
#   server_json_block = JSON content of the server (indented with 6 spaces).
# First call creates the file; subsequent calls inject without duplicating.
# ===========================================================================
inject_mcp_server() {
  local project_path="$1"
  local server_name="$2"
  local server_block="$3"

  local mcp_file="${project_path}/.vscode/mcp.json"
  mkdir -p "${project_path}/.vscode"

  # Already has this server? Skip
  if [[ -f "$mcp_file" ]] && grep -Fq "\"${server_name}\"" "$mcp_file"; then
    return 0
  fi

  if [[ ! -f "$mcp_file" ]]; then
    # Create new file with the first server
    cat > "$mcp_file" <<MCPEOF
{
  "servers": {
    "${server_name}": {
${server_block}
    }
  }
}
MCPEOF
    return 0
  fi

  # File exists -- inject new server before the closing braces
  # Sanity check: file must end with } to be valid JSON
  if ! tail -c 5 "$mcp_file" | grep -q '}'; then
    warn "mcp.json does not end with '}' -- cannot inject server '$server_name'"
    return 1
  fi
  local tmp
  tmp="$(make_temp)"
  # Dynamically find the last two closing braces (  } and }) instead of
  # hardcoding head -n -2 which breaks with trailing blank lines (#89/#111).
  local last_root_brace last_servers_brace
  last_root_brace="$(grep -n '^}' "$mcp_file" | tail -n1 | cut -d: -f1)"
  last_servers_brace="$(grep -n '^\s*}' "$mcp_file" | grep -v "^${last_root_brace}:" | tail -n1 | cut -d: -f1)"
  if [[ -z "$last_root_brace" || -z "$last_servers_brace" ]]; then
    warn "mcp.json: expected closing brace not found -- cannot inject server '$server_name'"
    return 1
  fi
  # 1. Everything up to (exclusive) the servers closing brace
  head -n "$((last_servers_brace - 1))" "$mcp_file" > "$tmp"
  # 2. Add comma to the closing of the last server
  sed -i '$ s/}$/},/' "$tmp"
  # 3. New server
  echo "    \"${server_name}\": {" >> "$tmp"
  echo "${server_block}" >> "$tmp"
  echo "    }" >> "$tmp"
  # 4. Close servers + root
  echo "  }" >> "$tmp"
  echo "}" >> "$tmp"
  mv "$tmp" "$mcp_file"
}

# ===========================================================================
# inject_vscode_extension -- Adds extension to the extensions array in devcontainer.json.
# Usage: inject_vscode_extension "$devcontainer_file" "extension.id"
# Idempotent: skip if extension already exists. Manages commas automatically.
# ===========================================================================
inject_vscode_extension() {
  local devcontainer="$1"
  local ext_id="$2"

  [[ -f "$devcontainer" ]] || return 0
  grep -Fq "$ext_id" "$devcontainer" && return 0

  # Find the line of ] that closes the extensions array
  local close_line
  close_line="$(awk '/"extensions"/{f=1} f && /\]/{print NR; exit}' "$devcontainer")"
  [[ -n "$close_line" ]] || return 0

  # Add comma to the last extension (line before ]) if it doesn't have one
  local prev_line=$((close_line - 1))
  if ! sed -n "${prev_line}p" "$devcontainer" | grep -q ',$'; then
    sed -i "${prev_line}s/\"$/\",/" "$devcontainer"
  fi

  # Insert the new extension before ]
  sed -i "${close_line}i\\        \"${ext_id}\"" "$devcontainer"
}

# ===========================================================================
# ensure_env_example -- Creates .env.example with standard header (no-clobber).
# Usage: ensure_env_example "$project_path"
# ===========================================================================
ensure_env_example() {
  local project_path="$1"
  local env_example="${project_path}/.env.example"
  if [[ ! -f "$env_example" ]]; then
    cat > "$env_example" <<'HEADER'
# Environment variables -- copy to .env and adjust values.
# .env is NOT versioned (.gitignore). .env.example is the reference.
HEADER
  fi
}

# ===========================================================================
# inject_compose_service -- Creates/updates compose.yaml with a service.
# Usage: inject_compose_service "$project_path" "service-name" "service_block" ["volume_block"]
#   service_block = YAML lines of the service (indented with 4 spaces).
#   volume_block  = YAML lines of the volume (indented with 2 spaces), optional.
# First call creates the skeleton file; subsequent calls inject without duplicating.
# ===========================================================================
inject_compose_service() {
  local project_path="$1"
  local service_name="$2"
  local service_block="$3"
  local volume_block="${4:-}"

  local compose_file="${project_path}/compose.yaml"

  # Idempotency: if service already exists, skip
  if [[ -f "$compose_file" ]] && grep -Fq "  ${service_name}:" "$compose_file"; then
    return 0
  fi

  # If compose.yaml doesn't exist, create skeleton
  if [[ ! -f "$compose_file" ]]; then
    cat > "$compose_file" <<'COMPOSEYAML'
services: {}

networks:
COMPOSEYAML
  fi

  # Inject service block BEFORE the first top-level section after services
  # (volumes: or networks:, whichever comes first).
  # If services is empty ({}), expand to mapping before injecting
  if grep -Fq 'services: {}' "$compose_file"; then
    sed -i 's/^services: {}$/services:/' "$compose_file"
  fi

  # Find the insertion line: first top-level section that is NOT services
  local insert_before=""
  insert_before="$(grep -n '^[a-z]' "$compose_file" | grep -v '^[0-9]*:services' | head -n1 | cut -d: -f1)"
  if [[ -n "$insert_before" ]]; then
    local tmp
    tmp="$(make_temp)"
    head -n "$((insert_before - 1))" "$compose_file" > "$tmp"
    echo "  ${service_name}:" >> "$tmp"
    echo "$service_block" >> "$tmp"
    echo "" >> "$tmp"
    tail -n "+${insert_before}" "$compose_file" >> "$tmp"
    mv "$tmp" "$compose_file"
  else
    # No networks section -- append at the end
    echo "" >> "$compose_file"
    echo "  ${service_name}:" >> "$compose_file"
    echo "$service_block" >> "$compose_file"
  fi

  # Inject volume (if provided and doesn't exist yet)
  if [[ -n "$volume_block" ]]; then
    local vol_name
    vol_name="$(echo "$volume_block" | head -n1 | sed 's/^[[:space:]]*//' | sed 's/:.*$//')"
    # Uses ^  (2 spaces) to match only the declaration under volumes:,
    # not the reference inside services (e.g. - postgres_data:/var/lib/...).
    if [[ -n "$vol_name" ]] && ! grep -Fq "  ${vol_name}:" "$compose_file"; then
      # Ensure volumes: section exists before inserting entry
      if ! grep -q '^volumes:' "$compose_file"; then
        local net_line
        net_line="$(grep -n '^networks:' "$compose_file" | head -n1 | cut -d: -f1)"
        if [[ -n "$net_line" ]]; then
          sed -i "${net_line}i\\volumes:" "$compose_file"
        else
          echo -e "\nvolumes:" >> "$compose_file"
        fi
      fi
        # Insert entry after volumes:
      local vol_tmp; vol_tmp="$(make_temp)"
      echo "$volume_block" > "$vol_tmp"
      sed -i "/^volumes:/r ${vol_tmp}" "$compose_file" 
    fi
  fi
}

# ===========================================================================
# Environment validations
# ===========================================================================
ensure_wsl() {
  is_wsl || die_hint "This script must run INSIDE WSL." \
    "You ran dropwsl.sh directly on Windows" \
    "Use the proxy: dropwsl <command>;Or enter WSL first: wsl -d Ubuntu-24.04"
}

ensure_sudo() {
  if ! has_cmd sudo; then
    die "sudo not found. (Ubuntu/WSL normally has it)."
  fi
}

# Reads ID and VERSION_CODENAME from /etc/os-release.
# Sets globals DISTRO_ID and DISTRO_CODENAME.
# Used by core installers that need distro-specific apt repos.
get_distro_info() {
  DISTRO_ID="$(sed -n 's/^ID=//p' /etc/os-release | tr -d '"')"
  DISTRO_CODENAME="$(sed -n 's/^VERSION_CODENAME=//p' /etc/os-release | tr -d '"')"
  if [[ -z "$DISTRO_ID" ]]; then
    die "Cannot detect distro ID from /etc/os-release"
  fi
  if [[ -z "$DISTRO_CODENAME" ]]; then
    die "Cannot detect VERSION_CODENAME from /etc/os-release"
  fi
}

ensure_supported_distro() {
  if [[ ! -f /etc/os-release ]]; then
    die "File /etc/os-release not found. Could not identify the distro."
  fi

  local distro_id distro_version distro_name
  distro_id="$(sed -n 's/^ID=//p' /etc/os-release | tr -d '"')"
  distro_version="$(sed -n 's/^VERSION_ID=//p' /etc/os-release | tr -d '"')"
  distro_name="$(sed -n 's/^PRETTY_NAME=//p' /etc/os-release | tr -d '"')"
  : "${distro_id:=unknown}" "${distro_version:=0}" "${distro_name:=${distro_id} ${distro_version}}"

  if ! printf '%s\n' "${SUPPORTED_DISTROS[@]}" | grep -Fqx "$distro_id"; then
    die "Distro '$distro_name' not supported. Use Ubuntu ${MIN_UBUNTU}+ or Debian ${MIN_DEBIAN}+."
  fi

  case "$distro_id" in
    ubuntu)
      if ! version_gte "$distro_version" "$MIN_UBUNTU"; then
        die "Ubuntu $distro_version is too old. Minimum: $MIN_UBUNTU."
      fi
      ;;
    debian)
      if ! version_gte "$distro_version" "$MIN_DEBIAN"; then
        die "Debian $distro_version is too old. Minimum: $MIN_DEBIAN."
      fi
      ;;
  esac

  log "Distro detected: $distro_name"
}

# ===========================================================================
# apt_base -- Updates apt and installs base packages
# ===========================================================================
apt_base() {
  # Skip if all base packages are already installed
  local base_pkgs=(ca-certificates curl wget git gnupg lsb-release)
  local all_installed=true
  local pkg
  for pkg in "${base_pkgs[@]}"; do
    if ! dpkg -s "$pkg" &>/dev/null; then
      all_installed=false
      break
    fi
  done

  if [[ "$all_installed" == true ]]; then
    log "Base packages already installed -- skipping apt update/upgrade"
  else
    log "Updating apt and installing base packages"
    run_quiet sudo apt-get update
    run_quiet sudo apt-get upgrade -y
    run_quiet sudo apt-get install -y "${base_pkgs[@]}"
  fi

  # Create keyrings directory (used by Docker, kubectl, Azure CLI, GitHub CLI)
  [[ -d /etc/apt/keyrings ]] || sudo install -m 0755 -d /etc/apt/keyrings
}

# ===========================================================================
# _ensure_dropwsl_symlink -- Ensures symlink and PATH for dropwsl.
# Called by clone_dropwsl_repo in all paths (fresh + update).
# ===========================================================================
_ensure_dropwsl_symlink() {
  [[ -f "${INSTALL_DIR}/dropwsl.sh" ]] || return 0

  mkdir -p "$BIN_DIR"
  ln -sf "${INSTALL_DIR}/dropwsl.sh" "$BIN_LINK"

  if [[ ":$PATH:" != *":${BIN_DIR}:"* ]]; then
    if ! grep -qF '.local/bin' "${HOME}/.bashrc" 2>/dev/null; then
      echo 'export PATH="${HOME}/.local/bin:${PATH}"' >> "${HOME}/.bashrc"
      log "${BIN_DIR} added to PATH in ~/.bashrc"
    fi
    export PATH="${BIN_DIR}:${PATH}"
  fi
}

# ===========================================================================
# clone_dropwsl_repo -- Clones repo to INSTALL_DIR and creates symlink.
# ===========================================================================
clone_dropwsl_repo() {
  # If INSTALL_DIR already has a valid dropwsl.sh -> just sync files
  if [[ -f "${INSTALL_DIR}/dropwsl.sh" ]]; then
    # If SCRIPT_DIR == INSTALL_DIR (running via symlink), nothing to sync
    local real_script real_install
    real_script="$(realpath "$SCRIPT_DIR" 2>/dev/null || echo "$SCRIPT_DIR")"
    real_install="$(realpath "$INSTALL_DIR" 2>/dev/null || echo "$INSTALL_DIR")"
    if [[ "$real_script" == "$real_install" ]]; then
      _ensure_dropwsl_symlink
      return 0
    fi
    log "dropwsl repository already exists at ${INSTALL_DIR}, syncing..."
    # Sync via tar (excluding .git/.old) -- fast and idempotent
    tar -C "$SCRIPT_DIR" --exclude='.git' --exclude='.old' --exclude='logs' -cf - . | tar -C "$INSTALL_DIR" -xf -
    chmod +x "${INSTALL_DIR}/dropwsl.sh"
    _ensure_dropwsl_symlink
    return 0
  fi

  # INSTALL_DIR exists but without dropwsl.sh -> incomplete, clean and recreate
  if [[ -d "$INSTALL_DIR" ]]; then
    local non_log_content
    non_log_content="$(find "$INSTALL_DIR" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)"
    [[ -n "$non_log_content" ]] && warn "${INSTALL_DIR} exists but is incomplete or outdated -- reinstalling" || true

    [[ "$INSTALL_DIR" == *"/dropwsl"* ]] || die "Invalid INSTALL_DIR: $INSTALL_DIR"
    INSTALL_DIR="$(realpath "$INSTALL_DIR")"
    rm -rf "$INSTALL_DIR"
  fi

  # Strategy: if running from a local checkout with a complete repo
  # (has .git + templates), copy directly -- fastest path
  # and does not depend on remote access (which may fail due to private repo,
  # no auth, or no network). Remote clone is only attempted when SCRIPT_DIR
  # does not have the complete repo (e.g. standalone execution, isolated script).
  if [[ -d "${SCRIPT_DIR}/.git" ]] && [[ -d "${SCRIPT_DIR}/templates" ]]; then
    log "Installing dropwsl from ${SCRIPT_DIR}"
    mkdir -p "$INSTALL_DIR"
    # Exclude .git/ and .old/ from copy -- DrvFs (/mnt/c/) is orders of magnitude
    # slower per file (cross-filesystem + Defender scanning).
    # .git contains 1000+ objects not needed in the deploy copy.
    # The PS1 proxy (Invoke-Update) already does rsync --exclude='.git'.
    tar -C "$SCRIPT_DIR" --exclude='.git' --exclude='.old' -cf - . | tar -C "$INSTALL_DIR" -xf -
    git -C "$INSTALL_DIR" init -q 2>/dev/null || true
    if [[ -n "$REPO_URL" ]]; then
      git -C "$INSTALL_DIR" remote add origin "$REPO_URL" 2>/dev/null \
        || git -C "$INSTALL_DIR" remote set-url origin "$REPO_URL" 2>/dev/null || true
    fi
  else
    if [[ -z "$REPO_URL" ]]; then
      die_hint "REPO_URL is empty -- cannot clone repository." \
        "config.yaml not loaded or repo.url missing;env var REPO_URL not set" \
        "Check config.yaml has repo.url defined;Set REPO_URL env var manually" \
        "grep 'url:' config.yaml"
    fi
    log "Cloning dropwsl repository to ${INSTALL_DIR}"
    if ! GIT_TERMINAL_PROMPT=0 git clone "$REPO_URL" "$INSTALL_DIR" 2>/dev/null; then
      rm -rf "$INSTALL_DIR"
      warn "Failed to clone repository: ${REPO_URL}"
      warn "Script continues working from the local directory."
      warn "Check the URL or your connection and try again with: dropwsl update"
      return 0
    fi
  fi
  chmod +x "${INSTALL_DIR}/dropwsl.sh"

  _ensure_dropwsl_symlink
  log "Templates available at ${INSTALL_DIR}/templates/"
}

# ===========================================================================
# update_self -- Updates the local repository via git pull.
# ===========================================================================
update_self() {
  local verbose="${1:-true}"

  if [[ ! -d "${INSTALL_DIR}/.git" ]]; then
    # Local install (cp -a from Windows) -- no .git, no git pull.
    # PS1 proxy syncs via cp -a; here we only ensure symlink.
    if [[ -f "${INSTALL_DIR}/dropwsl.sh" ]]; then
      _ensure_dropwsl_symlink
      if [[ "$verbose" == true ]]; then
        local ver; ver="$(tr -d '\r' < "${INSTALL_DIR}/VERSION" 2>/dev/null || echo unknown)"
        log "Local version: v${ver} (synced by Windows proxy)"
      fi
      return 0
    fi
    if [[ "$verbose" == true ]]; then
      die "Repository not found at ${INSTALL_DIR}. Run install.cmd first."
    fi
    return 0
  fi

  [[ "$verbose" == true ]] && log "Updating dropwsl..." || true
  GIT_TERMINAL_PROMPT=0 git -C "$INSTALL_DIR" fetch --quiet origin 2>/dev/null || { warn "No connection -- using local version."; return 0; }

  local old_commit
  old_commit="$(git -C "$INSTALL_DIR" rev-parse HEAD 2>/dev/null || echo unknown)"

  local stashed=false
  if ! git -C "$INSTALL_DIR" diff --quiet 2>/dev/null; then
    git -C "$INSTALL_DIR" stash --quiet 2>/dev/null && stashed=true
  fi

  GIT_TERMINAL_PROMPT=0 git -C "$INSTALL_DIR" pull --ff-only --quiet 2>/dev/null || { warn "Pull failed -- using local version."; }

  if [[ "$stashed" == true ]]; then
    git -C "$INSTALL_DIR" stash pop --quiet 2>/dev/null || {
      warn "Conflict restoring stash -- dropping stash; check $INSTALL_DIR"
      git -C "$INSTALL_DIR" stash drop --quiet 2>/dev/null || true
    }
  fi
  chmod +x "${INSTALL_DIR}/dropwsl.sh"
  _ensure_dropwsl_symlink

  if [[ "$verbose" == true ]]; then
    local new_commit new_version
    new_commit="$(git -C "$INSTALL_DIR" rev-parse HEAD 2>/dev/null || echo unknown)"
    new_version="$(tr -d '\r' < "${INSTALL_DIR}/VERSION" 2>/dev/null || echo unknown)"
    if [[ "$old_commit" == "$new_commit" ]]; then
      log "Already up to date: v${new_version} (${new_commit:0:7})"
    else
      local commit_count
      commit_count="$(git -C "$INSTALL_DIR" rev-list --count "${old_commit}..${new_commit}" 2>/dev/null || echo '?')"
      log "Updated: v${new_version} -- ${commit_count} new commit(s) (${old_commit:0:7} -> ${new_commit:0:7})"
    fi
  fi
}

# ===========================================================================
# load_config -- Reads config.yaml and populates global variables.
# Lightweight bash parser for simple YAML (flat keys, lists).
# Does not depend on yq/python/jq.
# ===========================================================================
load_config() {
  local config_file="${1:-}"
  [[ -f "$config_file" ]] || return 0  # no config = use defaults

  local line key value

  # -- Supported distros (scoped: distro -> supported) --
  local in_distro=false in_supported=false
  local -a supported_list=()
  while IFS= read -r line; do
    # Remove comments and trailing whitespace
    line="${line%%#*}"
    [[ -z "${line// /}" ]] && continue

    # Detect root section
    if [[ "$line" =~ ^[a-z] ]]; then
      [[ "$line" =~ ^distro: ]] && in_distro=true || in_distro=false
      in_supported=false
      continue
    fi

    if [[ "$line" =~ ^[[:space:]]+- ]] && [[ "$in_supported" == true ]]; then
      value="${line#*- }"
      value="${value//\"/}"
      value="${value// /}"
      supported_list+=("$value")
      continue
    else
      in_supported=false
    fi

    if [[ "$in_distro" == true ]] && [[ "$line" =~ supported: ]]; then
      in_supported=true
      continue
    fi
  done < "$config_file"
  if (( ${#supported_list[@]} > 0 )); then
    SUPPORTED_DISTROS=("${supported_list[@]}")
  fi

  # -- Simple key:value reading --
  # NOTE: global grep -- if a key appears in multiple sections, head -n1 picks the first.
  # Works as long as the searched keys are unique in config.yaml.
  _yaml_val() {
    local pattern="$1"
    local result
    result="$(grep -E "^[[:space:]]*${pattern}:" "$config_file" | head -n1 | sed 's/^[^:]*:[[:space:]]*//' | sed 's/^["\x27]//;s/["\x27]$//' | tr -d '\r')"
    echo "$result"
  }

  # Distro min versions
  local v
  v="$(_yaml_val 'ubuntu')"
  [[ -n "$v" ]] && MIN_UBUNTU="$v"
  v="$(_yaml_val 'debian')"
  [[ -n "$v" ]] && MIN_DEBIAN="$v"

  # Repo (context-aware: grep sob repo:)
  # NOTE: -A2/-A3/-A1 assumes fixed YAML depth. Works with the current config.yaml.
  v="$(grep -A2 '^repo:' "$config_file" 2>/dev/null | grep 'url:' | head -n1 | sed 's/^[^:]*:[[:space:]]*//' | sed 's/^["\x27]//;s/["\x27]$//' | tr -d '\r')"
  [[ -n "$v" ]] && REPO_URL="$v"
  v="$(grep -A3 '^repo:' "$config_file" 2>/dev/null | grep 'install_dir:' | head -n1 | sed 's/^[^:]*:[[:space:]]*//' | sed 's/^["\x27]//;s/["\x27]$//' | tr -d '\r')"
  [[ -n "$v" ]] && INSTALL_DIR="${v/#\~/$HOME}"

  # Projects (context-aware: grep sob projects:)
  local projects_dir_val
  projects_dir_val="$(grep -A1 '^projects:' "$config_file" 2>/dev/null | grep 'dir:' | sed 's/^[^:]*:[[:space:]]*//' | sed 's/^["\x27]//;s/["\x27]$//' | tr -d '\r')"
  [[ -n "$projects_dir_val" ]] && PROJECTS_DIR="${projects_dir_val/#\~/$HOME}"

  # Tool versions
  v="$(grep -A2 'kubectl:' "$config_file" | grep 'version:' | head -n1 | sed 's/^[^:]*:[[:space:]]*//' | sed 's/^["\x27]//;s/["\x27]$//' | tr -d '\r')"
  [[ -n "$v" ]] && KUBECTL_VERSION="$v"
  v="$(grep -A2 'kind:' "$config_file" | grep 'version:' | head -n1 | sed 's/^[^:]*:[[:space:]]*//' | sed 's/^["\x27]//;s/["\x27]$//' | tr -d '\r')"
  [[ -n "$v" ]] && KIND_VERSION="$v"
  v="$(grep -A2 'helm:' "$config_file" | grep 'version:' | head -n1 | sed 's/^[^:]*:[[:space:]]*//' | sed 's/^["\x27]//;s/["\x27]$//' | tr -d '\r')"
  [[ -n "$v" ]] && HELM_VERSION="$v"

  # wsl-vpnkit version (scoped: core -> wsl-vpnkit -> version)
  v="$(sed -n '/^core:/,/^[a-z]/{/^[a-z]/d;p}' "$config_file" | grep -FA2 'wsl-vpnkit:' | grep 'version:' | head -n1 | sed 's/^[^:]*:[[:space:]]*//' | sed 's/^["\x27]//;s/["\x27]$//' | tr -d '\r')"
  [[ -n "$v" ]] && WSL_VPNKIT_VERSION="$v"

  # Docker daemon config (scoped: core -> docker -> mtu/log_max_size/log_max_file)
  local _docker_section
  _docker_section="$(sed -n '/^core:/,/^[a-z]/{/^[a-z]/d;p}' "$config_file" | sed -n '/docker:/,/^  [a-z]/p')"
  v="$(echo "$_docker_section" | grep 'mtu:' | head -n1 | sed 's/^[^:]*:[[:space:]]*//' | tr -d '\r "')"
  [[ -n "$v" ]] && DOCKER_MTU="$v"
  v="$(echo "$_docker_section" | grep 'log_max_size:' | head -n1 | sed 's/^[^:]*:[[:space:]]*//' | sed 's/^["\x27]//;s/["\x27]$//' | tr -d '\r')"
  [[ -n "$v" ]] && DOCKER_LOG_MAX_SIZE="$v"
  v="$(echo "$_docker_section" | grep 'log_max_file:' | head -n1 | sed 's/^[^:]*:[[:space:]]*//' | tr -d '\r "')"
  [[ -n "$v" ]] && DOCKER_LOG_MAX_FILE="$v"

  # Gitleaks version (layers section)
  v="$(_yaml_val 'gitleaks_version')"
  [[ -n "$v" ]] && GITLEAKS_VERSION="$v"

  # MCP server versions (layers section)
  v="$(_yaml_val 'mcp_fetch_version')"
  [[ -n "$v" ]] && MCP_FETCH_VERSION="$v"
  v="$(_yaml_val 'mcp_git_version')"
  [[ -n "$v" ]] && MCP_GIT_VERSION="$v"
  v="$(_yaml_val 'mcp_github_version')"
  [[ -n "$v" ]] && MCP_GITHUB_VERSION="$v"

  # Enabled core tools (auto-discovery from lib/core/*.sh, except systemd/vscode which are implicit)
  # Scoped: reads enabled under core -> <tool> -> enabled
  ENABLED_CORE=()
  local core_list=()
  local _core_file
  for _core_file in "${SCRIPT_DIR}/lib/core/"*.sh; do
    [[ -f "$_core_file" ]] || continue
    local _core_name
    _core_name="$(basename "$_core_file" .sh)"
    # systemd and vscode are called explicitly, not via toggle
    [[ "$_core_name" == "systemd" || "$_core_name" == "vscode" || "$_core_name" == "git" ]] && continue
    core_list+=("$_core_name")
  done
  local tool_name
  for tool_name in "${core_list[@]}"; do
    local enabled_val
    enabled_val="$(sed -n '/^core:/,/^[a-z]/{/^[a-z]/d;p}' "$config_file" | grep -FA5 "${tool_name}:" | grep 'enabled:' | head -n1 | sed 's/^[^:]*:[[:space:]]*//' | tr -d '\r ')"
    if [[ "$enabled_val" != "false" ]]; then
      ENABLED_CORE+=("$tool_name")
    fi
  done

  # VS Code extensions (scoped: vscode -> extensions)
  local in_vscode=false in_extensions=false
  local -a ext_list=()
  while IFS= read -r line; do
    line="${line%%#*}"
    [[ -z "${line// /}" ]] && continue

    # Detect root section
    if [[ "$line" =~ ^[a-z] ]]; then
      [[ "$line" =~ ^vscode: ]] && in_vscode=true || in_vscode=false
      in_extensions=false
      continue
    fi

    if [[ "$line" =~ ^[[:space:]]+- ]] && [[ "$in_extensions" == true ]]; then
      value="${line#*- }"
      value="${value//\"/}"
      value="${value// /}"
      ext_list+=("$value")
      continue
    elif [[ "$in_extensions" == true ]]; then
      in_extensions=false
    fi

    if [[ "$in_vscode" == true ]] && [[ "$line" =~ extensions: ]]; then
      in_extensions=true
      continue
    fi
  done < "$config_file"
  if (( ${#ext_list[@]} > 0 )); then
    VSCODE_EXTENSIONS=("${ext_list[@]}")
  fi

  # Git defaults (scoped: git -> defaults -> entries)
  local in_git=false in_git_defaults=false
  while IFS= read -r line; do
    line="${line%%#*}"
    [[ -z "${line// /}" ]] && continue

    # Detect root section
    if [[ "$line" =~ ^[a-z] ]]; then
      [[ "$line" =~ ^git: ]] && in_git=true || in_git=false
      in_git_defaults=false
      continue
    fi

    if [[ "$in_git_defaults" == true ]]; then
      if [[ "$line" =~ ^[[:space:]]{3,}[a-z] ]]; then
        key="$(echo "$line" | sed 's/^[[:space:]]*//' | cut -d: -f1)"
        value="$(echo "$line" | sed 's/^[^:]*:[[:space:]]*//' | sed 's/[[:space:]]*$//' | sed 's/^["\x27]//;s/["\x27]$//' | tr -d '\r')"
        [[ -n "$key" ]] && [[ -n "$value" ]] && GIT_DEFAULTS["$key"]="$value"
        continue
      else
        in_git_defaults=false
      fi
    fi

    if [[ "$in_git" == true ]] && [[ "$line" =~ ^[[:space:]]+defaults: ]]; then
      in_git_defaults=true
      continue
    fi
  done < "$config_file"

  # Default layers (root-level defaults.layers)
  DEFAULT_LAYERS=()
  local in_root_defaults=false
  local in_defaults_layers=false
  while IFS= read -r line; do
    line="${line%%#*}"
    [[ -z "${line// /}" ]] && continue

    # Detect "defaults:" at root level (no indentation)
    if [[ "$line" =~ ^defaults: ]]; then
      in_root_defaults=true
      in_defaults_layers=false
      continue
    fi

    # Left the defaults block (another root key)
    if [[ "$in_root_defaults" == true ]] && [[ "$line" =~ ^[a-z] ]]; then
      in_root_defaults=false
      in_defaults_layers=false
      continue
    fi

    # Detect "layers:" inside defaults
    if [[ "$in_root_defaults" == true ]] && [[ "$line" =~ ^[[:space:]]+layers: ]]; then
      in_defaults_layers=true
      continue
    fi

    # Read list items
    if [[ "$in_defaults_layers" == true ]]; then
      if [[ "$line" =~ ^[[:space:]]+- ]]; then
        value="${line#*- }"
        value="${value//\"/}"
        value="${value// /}"
        value="$(echo "$value" | tr -d '\r')"
        [[ -n "$value" ]] && DEFAULT_LAYERS+=("$value")
        continue
      else
        in_defaults_layers=false
      fi
    fi
  done < "$config_file"

  unset -f _yaml_val
}

# ===========================================================================
# show_config -- Shows effective configuration (defaults merged with config.yaml).
# ===========================================================================
show_config() {
  echo ""
  echo "dropwsl v${DROPWSL_VERSION} -- Effective configuration"
  echo "========================================================="
  echo ""
  echo "distro:"
  echo "  supported: [$(printf '%s, ' "${SUPPORTED_DISTROS[@]}" | sed 's/, $//')]"
  echo "  min_versions:"
  echo "    ubuntu: ${MIN_UBUNTU}"
  echo "    debian: ${MIN_DEBIAN}"
  echo ""
  echo "repo:"
  echo "  url: ${REPO_URL}"
  echo "  install_dir: ${INSTALL_DIR}"
  echo ""
  echo "projects:"
  echo "  dir: ${PROJECTS_DIR}"
  echo ""
  echo "core (enabled):"
  if (( ${#ENABLED_CORE[@]} > 0 )); then
    local tool
    for tool in "${ENABLED_CORE[@]}"; do
      echo "  - ${tool}"
    done
  else
    echo "  (none)"
  fi
  echo ""
  echo "  versions:"
  echo "    kubectl: ${KUBECTL_VERSION}"
  echo "    kind: ${KIND_VERSION}"
  echo "    helm: ${HELM_VERSION}"
  echo ""
  echo "  docker.daemon:"
  echo "    mtu: ${DOCKER_MTU}"
  echo "    log_max_size: ${DOCKER_LOG_MAX_SIZE}"
  echo "    log_max_file: ${DOCKER_LOG_MAX_FILE}"
  echo ""
  echo "git.defaults:"
  local key
  for key in $(printf '%s\n' "${!GIT_DEFAULTS[@]}" | sort); do
    echo "  ${key}: ${GIT_DEFAULTS[$key]}"
  done
  echo ""
  echo "vscode.extensions:"
  local ext
  for ext in "${VSCODE_EXTENSIONS[@]}"; do
    echo "  - ${ext}"
  done
  echo ""
  echo "defaults.layers:"
  if (( ${#DEFAULT_LAYERS[@]} > 0 )); then
    local layer
    for layer in "${DEFAULT_LAYERS[@]}"; do
      echo "  - ${layer}"
    done
  else
    echo "  (none)"
  fi
  echo ""
  echo "layers:"
  echo "  gitleaks_version: ${GITLEAKS_VERSION:-not set}"
  echo ""
}

# ===========================================================================
# show_first_run_banner -- Shows post-install banner with summary + next steps.
# Shows only on first run (stores flag in INSTALL_DIR).
# ===========================================================================
show_first_run_banner() {
  local marker="${INSTALL_DIR}/.first-run-done"

  # Already shown? Skip
  [[ -f "$marker" ]] && return 0

  echo ""
  echo "  +-------------------------------------------------------+"
  echo "  |         dropwsl installed successfully!               |"
  echo "  +-------------------------------------------------------+"
  echo ""
  echo "  Installed tools:"

  local tool
  for tool in "${ENABLED_CORE[@]}"; do
    local ver=""
    case "$tool" in
      docker)     ver="$(docker --version 2>/dev/null | sed 's/Docker version //' | cut -d, -f1)" ;;
      kubectl)    ver="$(kubectl version --client --short 2>/dev/null | head -n1 || kubectl version --client 2>/dev/null | grep -oP 'v[\d.]+' | head -n1)" ;;
      kind)       ver="$(kind version 2>/dev/null | awk '{print $2}')" ;;
      helm)       ver="$(helm version --short 2>/dev/null)" ;;
      azure-cli)  ver="$(az version 2>/dev/null | grep -oP '"azure-cli": "\K[^"]+' || echo installed)" ;;
      github-cli) ver="$(gh --version 2>/dev/null | head -n1 | awk '{print $3}')" ;;
      wsl-vpnkit) ver="${WSL_VPNKIT_VERSION}"; systemctl is-active --quiet wsl-vpnkit 2>/dev/null && ver="${ver} (active)" || ver="${ver} (inactive)" ;;
    esac
    printf "    * %-15s %s\n" "$tool" "${ver:-installed}"
  done

  echo ""
  echo "  Next steps:"
  echo "    1. dropwsl new my-project python"
  echo "    2. Open in VS Code -> Reopen in Container"
  echo "    3. dropwsl layers  (see available layers)"
  echo ""
  echo "  Useful commands:"
  echo "    dropwsl doctor     environment diagnostics"
  echo "    dropwsl config     effective configuration"
  echo "    dropwsl --help     all commands"
  echo ""

  # Mark as shown
  mkdir -p "$(dirname "$marker")"
  touch "$marker"
}
