#!/usr/bin/env bash
# lib/validate.sh -- Post-install validation.
# Requires: common.sh sourced

[[ -n "${_VALIDATE_SH_LOADED:-}" ]] && return 0
_VALIDATE_SH_LOADED=1

# Shared helper: prints formatted message to terminal and log.
_check_msg() {
  local label="$1"; shift
  local color=''
  case "$label" in
    OK)   color='\033[32m' ;;  # green
    WARN) color='\033[33m' ;;  # yellow
    FAIL) color='\033[31m' ;;  # red
  esac
  local plain; plain="$(printf '%-4s - %s' "$label" "$*")"
  echo -e "${color}$(printf '%-4s' "$label")\033[0m - $*"
  [[ -n "${LOG_FILE:-}" ]] && echo "$plain" >> "$LOG_FILE" || true
}

# Runs all validation checks and prints aligned results.
validate_all() {
  log "FINAL VALIDATION (checks) -- dropwsl v${DROPWSL_VERSION}"
  local failures=0

  _ok()   { _check_msg 'OK' "$@"; }
  _fail() { _check_msg 'FAIL' "$@"; ((failures++)) || true; }
  _warn() { _check_msg 'WARN' "$@"; }

  # systemd
  if [[ "$(ps -p 1 -o comm=)" == "systemd" ]]; then
    _ok "systemd active (PID 1 = systemd)"
  else
    _fail "systemd is not active. Run: wsl --shutdown and reopen."
  fi

  # docker service
  local docker_service_active=false
  if systemctl is-active --quiet docker; then
    _ok "docker service active"
    docker_service_active=true
  else
    _fail "docker service not active (systemctl start docker)"
  fi

  # docker cli + compose
  if has_cmd docker; then
    _ok "docker CLI: $(docker --version)"
  else
    _fail "docker CLI not found"
  fi

  if docker compose version >/dev/null 2>&1; then
    _ok "docker compose: $(docker compose version)"
  else
    _fail "docker compose plugin not found"
  fi

  if docker buildx version >/dev/null 2>&1; then
    _ok "docker buildx: $(docker buildx version 2>/dev/null | head -n1)"
  else
    _warn "docker buildx plugin not found"
  fi

  # Check docker daemon without sg (which prompts for password in batch mode)
  # Skip if service already failed -- avoids unnecessary 10s timeout
  if ! $docker_service_active; then
    _warn "docker daemon check skipped (service not active)"
  elif timeout 5 docker info >/dev/null 2>&1; then
    _ok "docker daemon responding (docker group active)"
  elif id -nG "$USER" 2>/dev/null | grep -qw docker; then
    _warn "docker group configured but not active in this session (reopen WSL)"
  else
    _fail "docker daemon not responding -- user not in docker group (run: dropwsl install and reopen terminal)"
  fi

  # kubectl
  if has_cmd kubectl; then
    _ok "kubectl: $(kubectl version --client 2>/dev/null | head -n1)"
  else
    _warn "kubectl not installed"
  fi

  # kind
  if has_cmd kind; then
    _ok "kind: $(kind version 2>/dev/null | awk '{print $2}' || echo installed)"
  else
    _warn "kind not installed"
  fi

  # helm
  if has_cmd helm; then
    _ok "helm: $(helm version --short 2>/dev/null || echo installed)"
  else
    _warn "helm not installed"
  fi

  # az
  if has_cmd az; then
    _ok "az CLI installed"
  else
    _warn "az CLI not installed"
  fi

  # gh
  if has_cmd gh; then
    _ok "gh CLI: $(gh --version | head -n 1)"
  else
    _warn "gh not installed"
  fi

  # wsl-vpnkit
  if systemctl is-active --quiet wsl-vpnkit 2>/dev/null; then
    _ok "wsl-vpnkit service active"
  elif [[ -f /etc/systemd/system/wsl-vpnkit.service ]]; then
    _warn "wsl-vpnkit service installed but not active"
  else
    _warn "wsl-vpnkit not installed (VPN users may lack access to private endpoints)"
  fi

  # GCM
  local gcm_helper
  gcm_helper="$(git config --global credential.helper 2>/dev/null || true)"
  if [[ "$gcm_helper" == *"git-credential-manager"* ]]; then
    _ok "GCM configured: ${gcm_helper}"
  else
    _warn "GCM not configured (git credential helper: ${gcm_helper:-none})"
  fi

  # Git defaults
  local key val actual
  for key in "${!GIT_DEFAULTS[@]}"; do
    val="${GIT_DEFAULTS[$key]}"
    actual="$(git config --global "$key" 2>/dev/null || true)"
    if [[ "$actual" == "$val" ]]; then
      _ok "git ${key} = ${val}"
    else
      _warn "git ${key} is not '${val}' (current: ${actual:-not set})"
    fi
  done

  # VS Code extensions
  if has_cmd cmd.exe; then
    local installed_extensions
    installed_extensions="$(cmd.exe /c "code --list-extensions" 2>/dev/null | tr -d '\r' || true)"
    if [[ -n "$installed_extensions" ]]; then
      local ext
      for ext in "${VSCODE_EXTENSIONS[@]}"; do
        if echo "$installed_extensions" | grep -qixF "$ext"; then
          _ok "VS Code ext: $ext"
        else
          _warn "VS Code ext not installed: $ext"
        fi
      done
    else
      _warn "VS Code (code) not found on Windows -- extensions not checked"
    fi
  else
    _warn "cmd.exe not available -- VS Code extensions not checked"
  fi

  # repo installed
  if [[ -f "${INSTALL_DIR}/dropwsl.sh" ]]; then
    _ok "repo installed at ${INSTALL_DIR}"
  else
    _warn "repo not found at ${INSTALL_DIR}"
  fi

  # symlink dropwsl
  if [[ -L "$BIN_LINK" ]]; then
    _ok "'dropwsl' command available (${BIN_LINK})"
  else
    _warn "symlink not found at ${BIN_LINK} (run --install to create)"
  fi

  # templates
  if [[ -d "${SCRIPT_DIR}/templates/devcontainer" ]]; then
    _ok "templates available via ${SCRIPT_DIR}"
  elif [[ -d "${INSTALL_DIR}/templates/devcontainer" ]]; then
    _ok "templates available at ${INSTALL_DIR}"
  else
    _warn "templates not found (--scaffold/--new may fail)"
  fi

  _say() { echo "$@"; [[ -n "${LOG_FILE:-}" ]] && echo "$@" >> "$LOG_FILE" || true; }

  _say ""
  _say "========================================="
  _say "  Manual one-time steps:"
  _say ""
  _say "  - Reopen WSL for the docker group to take effect (or: newgrp docker)"
  _say "  - GitHub auth:  gh auth login --web"
  _say "  - Copilot CLI:  gh copilot"
  _say ""
  _say "  Quick test:"
  _say "    docker run hello-world"
  _say "    kind create cluster && kubectl get nodes"
  _say "========================================="

  if [[ -n "${LOG_FILE:-}" ]]; then
    _say ""
    _say "Full log: $LOG_FILE"
  fi

  unset -f _ok _fail _warn _say

  if [[ "$failures" -gt 0 ]]; then
    echo
    warn "$failures check(s) failed."
    warn "Run: dropwsl update  |  wsl --shutdown + reopen  |  See docs/TROUBLESHOOTING.md"
    return 1
  fi
}

# ===========================================================================
# doctor -- Proactive diagnostics. Superset of validate.
# Runs all checks + extras, collects all issues and displays
# probable cause + solution for each (never aborts on first error).
# ===========================================================================
run_doctor() {
  log "dropwsl Doctor v${DROPWSL_VERSION} -- proactive diagnostics"
  local issues=0

  _doc_ok()   { _check_msg 'OK' "$@"; }
  _doc_issue() {
    local check="$1" causes="$2" solutions="$3" manual="${4:-}"
    _check_msg 'FAIL' "$check"

    echo -e "         \033[33mProbable causes:\033[0m"
    local IFS=';'
    local item
    set -f
    for item in $causes; do
      item="$(echo "$item" | sed 's/^[[:space:]]*//')"
      [[ -n "$item" ]] && echo "           - $item"
    done

    echo -e "         \033[32mSolutions:\033[0m"
    local i=1
    for item in $solutions; do
      item="$(echo "$item" | sed 's/^[[:space:]]*//')"
      [[ -n "$item" ]] && { echo "           $i. $item"; ((i++)); }
    done
    set +f

    if [[ -n "$manual" ]]; then
      echo -e "         \033[36mVerify:\033[0m \$ $manual"
    fi
    echo ""
    ((issues++)) || true
  }
  _doc_warn() { _check_msg 'WARN' "$@"; }

  echo ""
  echo "-- Core checks ------------------------------------------"

  # systemd
  if [[ "$(ps -p 1 -o comm= 2>/dev/null)" == "systemd" ]]; then
    _doc_ok "systemd active (PID 1 = systemd)"
  else
    _doc_issue "systemd is not active" \
      "WSL was not restarted after enabling systemd;/etc/wsl.conf does not have [boot] systemd=true" \
      "Run on Windows: wsl --shutdown and reopen WSL;Check /etc/wsl.conf -> [boot] systemd=true;Run: dropwsl update" \
      "ps -p 1 -o comm="
  fi

  # docker service
  if systemctl is-active --quiet docker 2>/dev/null; then
    _doc_ok "docker service active"
  else
    _doc_issue "docker service not active" \
      "systemd is not running;Docker was not installed;Docker service failed to start" \
      "Run: sudo systemctl start docker;Run: dropwsl install (reinstalls);Check: systemctl status docker" \
      "systemctl is-active docker"
  fi

  # docker cli
  if has_cmd docker; then
    _doc_ok "docker CLI: $(docker --version 2>/dev/null)"
  else
    _doc_issue "docker CLI not found" \
      "Docker Engine not installed;PATH does not include /usr/bin" \
      "Run: dropwsl install" \
      "which docker"
  fi

  # docker compose
  if docker compose version >/dev/null 2>&1; then
    _doc_ok "docker compose: $(docker compose version 2>/dev/null)"
  else
    _doc_issue "docker compose plugin not found" \
      "Compose plugin not installed;Old Docker version without compose v2" \
      "Run: sudo apt-get install docker-compose-plugin;Run: dropwsl install" \
      "docker compose version"
  fi

  # docker daemon
  if timeout 10 docker info >/dev/null 2>&1; then
    _doc_ok "docker daemon responding"
  elif id -nG "$USER" 2>/dev/null | grep -qw docker && ! id -nG 2>/dev/null | grep -qw docker; then
    _doc_warn "docker group added but not active in this session (reopen WSL)"
  else
    _doc_issue "docker daemon not responding" \
      "User not in docker group;Docker service not running;Socket /var/run/docker.sock lacks permissions" \
      "Run: newgrp docker (or reopen WSL);Run: sudo systemctl start docker;Run: dropwsl install" \
      "docker info"
  fi

  # kubectl, kind, helm, az, gh — optional
  if has_cmd kubectl; then _doc_ok "kubectl: $(kubectl version --client 2>/dev/null | head -n1)"
  else _doc_warn "kubectl not installed"; fi

  if has_cmd kind; then _doc_ok "kind: $(kind version 2>/dev/null | awk '{print $2}' || echo installed)"
  else _doc_warn "kind not installed"; fi

  if has_cmd helm; then _doc_ok "helm: $(helm version --short 2>/dev/null || echo installed)"
  else _doc_warn "helm not installed"; fi

  if has_cmd az; then _doc_ok "az CLI installed"
  else _doc_warn "az CLI not installed"; fi

  if has_cmd gh; then _doc_ok "gh CLI: $(gh --version 2>/dev/null | head -n 1)"
  else _doc_warn "gh not installed"; fi

  echo ""
  echo "-- Network ----------------------------------------------"

  # wsl-vpnkit (VPN tunnel)
  if systemctl is-active --quiet wsl-vpnkit 2>/dev/null; then
    _doc_ok "wsl-vpnkit service active (VPN traffic tunneled through Windows)"
  elif [[ -f /etc/systemd/system/wsl-vpnkit.service ]]; then
    _doc_issue "wsl-vpnkit service installed but not active" \
      "Service failed to start;wsl-vpnkit distro not imported;wsl.exe interop disabled" \
      "Check: systemctl status wsl-vpnkit;Verify distro: wsl -l -v | grep wsl-vpnkit;Run: dropwsl install" \
      "systemctl status wsl-vpnkit"
  elif wsl.exe -l -q 2>/dev/null | tr -d '\0\r' | grep -qx 'wsl-vpnkit'; then
    _doc_warn "wsl-vpnkit distro exists but service not configured in this distro"
  else
    _doc_warn "wsl-vpnkit not installed (VPN users may lack access to private endpoints)"
  fi

  # VPN private endpoint connectivity
  if curl -s --connect-timeout 3 --max-time 5 https://login.microsoftonline.com >/dev/null 2>&1; then
    _doc_ok "Azure AD endpoint reachable (login.microsoftonline.com)"
  else
    if systemctl is-active --quiet wsl-vpnkit 2>/dev/null; then
      _doc_issue "Azure AD endpoint unreachable despite wsl-vpnkit running" \
        "wsl-vpnkit service may need restart;VPN not connected on Windows;Corporate firewall blocking" \
        "Restart: sudo systemctl restart wsl-vpnkit;Try: wsl --shutdown and reopen;Check VPN status on Windows" \
        "curl -sS --max-time 5 https://login.microsoftonline.com"
    else
      _doc_warn "Azure AD endpoint unreachable (login.microsoftonline.com) -- expected if VPN active without wsl-vpnkit"
    fi
  fi

  # DNS -- single-shot intentional: doctor diagnoses current network state,
  # retry would mask the real issue the user wants to see
  if curl -s --connect-timeout 5 --max-time 10 https://api.github.com >/dev/null 2>&1; then
    _doc_ok "DNS and internet working (api.github.com)"
  else
    _doc_issue "Failed to connect to api.github.com" \
      "No internet connection;DNS not resolving (problem in .wslconfig or resolv.conf);Corporate proxy blocking;Firewall blocking" \
      "Check: curl -v https://api.github.com;If using proxy, configure http_proxy and https_proxy;Check /etc/resolv.conf;Try: wsl --shutdown and reopen" \
      "curl -s --connect-timeout 5 https://api.github.com"
  fi

  echo ""
  echo "-- Disk -------------------------------------------------"

  # Disk space /
  local disk_avail
  disk_avail="$(df -BG / 2>/dev/null | awk 'NR==2 {print $4}' | tr -d 'G')"
  if [[ -n "$disk_avail" ]] && (( disk_avail >= 5 )); then
    _doc_ok "Disk space on / : ${disk_avail}G available"
  elif [[ -n "$disk_avail" ]]; then
    _doc_issue "Low disk space on / : ${disk_avail}G available" \
      "Disk nearly full;Too many Docker images or caches" \
      "Free space: docker system prune -a;Remove caches: sudo apt-get clean" \
      "df -h /"
  fi

  echo ""
  echo "-- Configuration ----------------------------------------"

  # GCM
  local gcm_helper
  gcm_helper="$(git config --global credential.helper 2>/dev/null || true)"
  if [[ "$gcm_helper" == *"git-credential-manager"* ]]; then
    _doc_ok "GCM configured"
  else
    _doc_warn "GCM not configured (credential helper: ${gcm_helper:-none})"
  fi

  # symlink
  if [[ -L "$BIN_LINK" ]]; then
    _doc_ok "'dropwsl' command available (${BIN_LINK})"
  else
    _doc_issue "symlink dropwsl not found" \
      "install did not complete;BIN_DIR does not exist" \
      "Run: dropwsl install" \
      "ls -la $BIN_LINK"
  fi

  # wsl version (if cmd.exe available)
  if has_cmd cmd.exe; then
    local wsl_ver
    wsl_ver="$(cmd.exe /c "wsl --version" 2>/dev/null | tr -d '\0\r' | head -n1 || true)"
    if [[ -n "$wsl_ver" ]]; then
      _doc_ok "WSL: ${wsl_ver}"
    fi
  fi

  echo ""
  echo "-- .wslconfig -------------------------------------------"

  # Read .wslconfig from the Windows user profile
  local wslconfig_path=""
  if [[ -n "${USERPROFILE:-}" ]]; then
    wslconfig_path="$(wslpath -u "$USERPROFILE" 2>/dev/null || true)/.wslconfig"
  fi
  if [[ -z "$wslconfig_path" ]] && has_cmd cmd.exe; then
    local win_profile
    win_profile="$(cmd.exe /c "echo %USERPROFILE%" 2>/dev/null | tr -d '\r\0' || true)"
    [[ -n "$win_profile" ]] && wslconfig_path="$(wslpath -u "$win_profile" 2>/dev/null || true)/.wslconfig"
  fi

  if [[ -z "$wslconfig_path" ]] || [[ ! -f "$wslconfig_path" ]]; then
    _doc_issue ".wslconfig not found" \
      "install.ps1 was not run;File was deleted manually" \
      "Run: install.cmd (creates .wslconfig automatically)" \
      "cat \"\$USERPROFILE/.wslconfig\""
  else
    _doc_ok ".wslconfig found: $wslconfig_path"

    # Helper: read a key from [wsl2] section
    _wslcfg_val() {
      local key="$1"
      sed -n '/^\[wsl2\]/,/^\[/{/^'"$key"'=/p}' "$wslconfig_path" 2>/dev/null \
        | head -n1 | sed 's/^[^=]*=//' | tr -d '\r '
    }

    # processors check
    local cfg_proc; cfg_proc="$(_wslcfg_val 'processors')"
    # WSL virtualizes /proc/cpuinfo — query Windows host via interop for real total
    local total_cores=""
    total_cores="$(cmd.exe /c "echo %NUMBER_OF_PROCESSORS%" 2>/dev/null | tr -d '\r' | grep -oE '[0-9]+' || true)"
    if [[ -z "$total_cores" ]]; then
      total_cores="$(nproc 2>/dev/null || echo '')"
    fi
    if [[ -z "$cfg_proc" ]]; then
      _doc_warn "processors not set in .wslconfig (WSL uses all cores -- may starve Windows)"
    elif [[ -n "$total_cores" ]] && (( cfg_proc >= total_cores )); then
      _doc_warn "processors=${cfg_proc} uses all ${total_cores} host cores (no cores reserved for Windows)"
    else
      _doc_ok "processors=${cfg_proc} (host has ${total_cores:-?} cores)"
    fi

    # memory check
    local cfg_mem; cfg_mem="$(_wslcfg_val 'memory')"
    if [[ -z "$cfg_mem" ]]; then
      _doc_warn "memory not set in .wslconfig (WSL may consume all RAM -- vmmem)"
    else
      # Extract numeric GB value for analysis
      local mem_num; mem_num="$(echo "$cfg_mem" | grep -oE '[0-9]+' | head -n1)"
      # WSL virtualizes /proc/meminfo — query Windows host via interop for real total
      local total_mem_gb=""
      local host_mem_kb=""
      host_mem_kb="$(wmic.exe OS get TotalVisibleMemorySize /value 2>/dev/null | tr -d '\r' | grep -oE '[0-9]+' || true)"
      if [[ -n "$host_mem_kb" ]]; then
        total_mem_gb=$(( host_mem_kb / 1048576 ))
      fi
      # Fallback to /proc/meminfo (better than nothing, but may reflect WSL limit)
      if [[ -z "$total_mem_gb" ]] || (( total_mem_gb == 0 )); then
        local fallback_kb; fallback_kb="$(grep -i '^MemTotal:' /proc/meminfo 2>/dev/null | awk '{print $2}')"
        if [[ -n "$fallback_kb" ]]; then
          total_mem_gb=$(( fallback_kb / 1048576 ))
        fi
      fi
      if [[ -n "$mem_num" ]] && [[ -n "$total_mem_gb" ]] && (( total_mem_gb > 0 )); then
        local pct=$(( mem_num * 100 / total_mem_gb ))
        if (( pct > 70 )); then
          _doc_warn "memory=${cfg_mem} is ${pct}% of host ${total_mem_gb}GB (>70% may starve Windows)"
        else
          _doc_ok "memory=${cfg_mem} (${pct}% of host ${total_mem_gb}GB)"
        fi
      else
        _doc_ok "memory=${cfg_mem}"
      fi
    fi

    # swap check
    local cfg_swap; cfg_swap="$(_wslcfg_val 'swap')"
    if [[ -n "$cfg_swap" ]]; then
      local swap_num; swap_num="$(echo "$cfg_swap" | grep -oE '[0-9]+' | head -n1)"
      if [[ -n "$swap_num" ]] && (( swap_num > 4 )); then
        _doc_warn "swap=${cfg_swap} is large (>4GB degrades IO and masks memory issues)"
      else
        _doc_ok "swap=${cfg_swap}"
      fi
    else
      _doc_ok "swap not set (WSL default)"
    fi

    # networkingMode check
    local cfg_net; cfg_net="$(_wslcfg_val 'networkingMode')"
    if [[ "$cfg_net" == "mirrored" ]]; then
      _doc_ok "networkingMode=mirrored"
    elif [[ -z "$cfg_net" ]]; then
      _doc_warn "networkingMode not set (default: NAT -- mirrored recommended for enterprise)"
    else
      _doc_ok "networkingMode=${cfg_net}"
    fi

    unset -f _wslcfg_val
  fi

  echo ""
  echo "========================================================="
  if [[ "$issues" -gt 0 ]]; then
    echo "  $issues issue(s) found. See solutions above."
    echo "  General fix: dropwsl install (fixes most issues)"
  else
    echo "  No issues found. Environment healthy."
  fi
  echo "========================================================="
  echo ""

  if [[ -n "${LOG_FILE:-}" ]]; then
    echo "Log: $LOG_FILE"
    echo ""
  fi

  unset -f _doc_ok _doc_issue _doc_warn

  [[ "$issues" -gt 0 ]] && return 1 || return 0
}
