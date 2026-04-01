#!/usr/bin/env bash
# lib/core/systemd.sh -- Ensures systemd is enabled in WSL.
# Requires: common.sh sourced

[[ -n "${_SYSTEMD_SH_LOADED:-}" ]] && return 0
_SYSTEMD_SH_LOADED=1

# Ensures systemd is enabled in /etc/wsl.conf.
# If the file needs to be changed, forces wsl --shutdown so the change
# takes effect on the next distro boot.
enable_systemd_if_needed() {
  local wslconf="/etc/wsl.conf"
  local need_shutdown="false"

  if [[ ! -f "$wslconf" ]] || ! grep -qE '^\s*systemd\s*=\s*true' "$wslconf"; then
    log "Enabling systemd in WSL via /etc/wsl.conf"
    if [[ ! -f "$wslconf" ]]; then
      sudo tee "$wslconf" >/dev/null <<'EOF'
[boot]
systemd=true
EOF
    elif grep -q '^\[boot\]' "$wslconf"; then
      sudo sed -i '/^\[boot\]/,/^\[/{s/^\s*systemd\s*=.*/systemd=true/}' "$wslconf"
      if ! grep -qE '^\s*systemd\s*=\s*true' "$wslconf"; then
        sudo sed -i '/^\[boot\]/a systemd=true' "$wslconf"
      fi
    else
      printf '\n[boot]\nsystemd=true\n' | sudo tee -a "$wslconf" >/dev/null
    fi
    need_shutdown="true"
  fi

  if [[ "$(ps -p 1 -o comm=)" != "systemd" ]]; then
    if [[ "$need_shutdown" == "true" ]]; then
      warn "systemd was enabled, but is not yet active in this session."
      warn "Shutting down WSL now. Reopen Ubuntu and run the script again."
      if has_cmd wsl.exe; then
        wsl.exe --shutdown
        # NOTE: after --shutdown WSL terminates this session. Code below is unreachable.
        # install.ps1 detects the exit and re-executes dropwsl.sh.
      else
        die "wsl.exe not found. Run on Windows: wsl --shutdown"
      fi
      return 0
    else
      die_hint "systemd is NOT active (PID 1 != systemd). Docker and other services will not work." \
        "WSL was not restarted after enabling systemd;/etc/wsl.conf already has systemd=true but requires restart" \
        "On Windows, run: wsl --shutdown;Reopen the Ubuntu terminal and run dropwsl again" \
        "ps -p 1 -o comm="
    fi
  fi
}
