#!/usr/bin/env bash
# lib/core/wsl-vpnkit.sh -- Installs wsl-vpnkit (VPN connectivity for WSL 2).
# Requires: common.sh sourced (WSL_VPNKIT_VERSION)

[[ -n "${_WSL_VPNKIT_SH_LOADED:-}" ]] && return 0
_WSL_VPNKIT_SH_LOADED=1

# Checks if the wsl-vpnkit distro is already imported.
_vpnkit_distro_exists() {
  wsl.exe -l -q 2>/dev/null | tr -d '\0\r' | grep -qx 'wsl-vpnkit'
}

# Creates the systemd service file that invokes wsl-vpnkit from the host distro.
# The service runs wsl.exe -d wsl-vpnkit, so the binaries live in the dedicated
# Alpine distro while the service is managed by the user's main distro.
_setup_vpnkit_service() {
  local service_file="/etc/systemd/system/wsl-vpnkit.service"
  if [[ -f "$service_file" ]]; then
    log "wsl-vpnkit service file already exists"
  else
    log "Creating wsl-vpnkit systemd service"
    sudo tee "$service_file" >/dev/null <<'EOF'
[Unit]
Description=wsl-vpnkit
After=network.target
Before=docker.service

[Service]
ExecStart=/mnt/c/Windows/system32/wsl.exe -d wsl-vpnkit --cd /app wsl-vpnkit
Restart=always
KillMode=mixed

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
  fi
  run_quiet sudo systemctl enable wsl-vpnkit
  run_quiet sudo systemctl start wsl-vpnkit

  # Wait for service to become active
  local wait_count=0
  while ! systemctl is-active --quiet wsl-vpnkit 2>/dev/null; do
    if (( wait_count >= 10 )); then
      warn "wsl-vpnkit service did not become active after 10s"
      return 0
    fi
    sleep 1
    ((wait_count++)) || true
  done
  log "wsl-vpnkit service is active"
}

install_wsl-vpnkit() {
  # Idempotency: if distro exists and service is running, nothing to do
  if _vpnkit_distro_exists; then
    log "wsl-vpnkit already installed (distro imported)"
    if systemctl is-active --quiet wsl-vpnkit 2>/dev/null; then
      log "wsl-vpnkit service already active"
      return 0
    fi
    # Distro exists but service not configured — set it up
    _setup_vpnkit_service
    return 0
  fi

  log "Installing wsl-vpnkit ${WSL_VPNKIT_VERSION} (VPN tunnel for WSL)"

  # wsl.exe --import needs a Windows path for the tarball.
  # Download to /tmp (Linux), convert path via wslpath.
  local tmptar
  tmptar="$(make_temp).tar.gz"
  local download_url="https://github.com/sakai135/wsl-vpnkit/releases/download/${WSL_VPNKIT_VERSION}/wsl-vpnkit.tar.gz"
  curl_retry -fLo "$tmptar" "$download_url" \
    || die_hint "Failed to download wsl-vpnkit ${WSL_VPNKIT_VERSION}" \
      "Network issue;GitHub releases unreachable;Version does not exist" \
      "Check: curl -fLo /dev/null ${download_url};Verify version at https://github.com/sakai135/wsl-vpnkit/releases" \
      "curl -fsSL ${download_url} -o /dev/null -w '%{http_code}'"

  # Convert Linux path to Windows path for wsl.exe --import
  local win_tar_path
  win_tar_path="$(wslpath -w "$tmptar" 2>/dev/null || true)"
  if [[ -z "$win_tar_path" ]]; then
    die "Failed to convert path '$tmptar' to Windows format (wslpath -w)"
  fi

  # Determine Windows install directory: %USERPROFILE%\wsl-vpnkit
  local win_profile
  win_profile="$(cmd.exe /c "echo %USERPROFILE%" 2>/dev/null | tr -d '\r\0')"
  if [[ -z "$win_profile" ]]; then
    die "Failed to get Windows USERPROFILE"
  fi
  local install_dir="${win_profile}\\wsl-vpnkit"

  log "Importing wsl-vpnkit distro (${install_dir})"
  wsl.exe --import wsl-vpnkit --version 2 "$install_dir" "$win_tar_path"
  if [[ $? -ne 0 ]] || ! _vpnkit_distro_exists; then
    die_hint "Failed to import wsl-vpnkit distro" \
      "Insufficient disk space;WSL 2 not enabled;Antivirus blocking import" \
      "Check disk space on C: drive;Run: wsl --status;Try importing manually: wsl --import wsl-vpnkit --version 2 ${install_dir} <path-to-tar>" \
      "wsl -l -v"
  fi
  log "wsl-vpnkit distro imported successfully"

  _setup_vpnkit_service
}
