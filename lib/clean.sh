#!/usr/bin/env bash
# lib/clean.sh -- Tool removal (clean and clean-soft).
# Requires: common.sh sourced

[[ -n "${_CLEAN_SH_LOADED:-}" ]] && return 0
_CLEAN_SH_LOADED=1

# Shows instructions for full WSL distro reset.
clean_all() {
  local distro_name="${WSL_DISTRO_NAME:-}"
  if [[ -z "$distro_name" ]]; then
    # Fallback: extract from /etc/os-release (e.g. "Ubuntu")
    distro_name="$(. /etc/os-release 2>/dev/null && echo "${NAME:-}" || true)"
  fi
  if [[ -z "$distro_name" ]]; then
    die "Could not detect WSL distro name. Run 'wsl -l -v' in CMD to check."
  fi

  log "RESET -- reinstall WSL distro '${distro_name}' from scratch"
  echo
  warn "This command CANNOT be run from inside WSL (VS Code bash, Ubuntu terminal, etc.)."
  warn "Running 'wsl --unregister' from inside WSL kills the session and may corrupt data."
  echo
  echo "For a full reset, run in Windows Command Prompt (CMD):"
  echo
  echo "  wsl --unregister ${distro_name}"
  echo "  wsl --unregister wsl-vpnkit    (optional, if installed)"
  echo "  wsl --install ${distro_name}"
  echo
  echo "To remove only the tools without destroying the distro (works here in WSL):"
  echo "  ./dropwsl.sh --clean-soft"
}

# Removes all tools installed by dropwsl without destroying the distro.
clean_soft() {
  sudo true 2>/dev/null || { warn "sudo unavailable -- aborting clean-soft"; return 1; }
  log "PARTIAL CLEANUP -- removing tools without destroying the distro"

  if [[ "$ASSUME_YES" != true ]]; then
    echo
    echo "This will remove: Docker, kubectl, kind, helm, Azure CLI, GitHub CLI,"
    echo "GCM, wsl-vpnkit service, VS Code extensions (Windows side) and the cloned dropwsl repository."
    echo "Note: the wsl-vpnkit distro is shared across all WSL distros and will NOT be removed."
    echo
    local confirm
    read -rp "Are you sure? (y/N) " confirm
    [[ "$confirm" =~ ^[yY]$ ]] || { echo "Cancelled."; return 0; }
  fi

  # wsl-vpnkit service (distro is NOT removed -- shared across all WSL distros)
  if [[ -f /etc/systemd/system/wsl-vpnkit.service ]]; then
    log "Stopping wsl-vpnkit service"
    sudo systemctl stop wsl-vpnkit 2>/dev/null || true
    sudo systemctl disable wsl-vpnkit 2>/dev/null || true
    sudo rm -f /etc/systemd/system/wsl-vpnkit.service
    sudo systemctl daemon-reload 2>/dev/null || true
  fi

  # kind clusters
  if has_cmd kind; then
    log "Removing existing kind clusters"
    local cluster
    for cluster in $(kind get clusters 2>/dev/null); do
      kind delete cluster --name "$cluster" || true
    done
  fi

  # Docker
  log "Removing Docker Engine"
  sudo systemctl stop docker docker.socket containerd 2>/dev/null || true
  sudo systemctl disable docker docker.socket containerd 2>/dev/null || true
  sudo gpasswd -d "$USER" docker 2>/dev/null || true
  run_quiet sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-buildx-plugin 2>/dev/null || true
  sudo rm -f /etc/apt/sources.list.d/docker.list
  sudo rm -f /etc/apt/keyrings/docker.gpg
  sudo rm -f /etc/docker/daemon.json
  if [[ -d /var/lib/docker ]]; then
    local _do_rm=false
    if [[ "$ASSUME_YES" == true ]]; then
      _do_rm=true
    else
      local rm_docker_data
      read -rp "Remove Docker data (/var/lib/docker)? (y/N) " rm_docker_data
      [[ "$rm_docker_data" =~ ^[yY]$ ]] && _do_rm=true
    fi
    if [[ "$_do_rm" == true ]]; then
      # Unmount any leftover Docker overlay/mount points before removing
      local _mnt
      while IFS= read -r _mnt; do
        sudo umount "$_mnt" 2>/dev/null || true
      done < <(awk '$2 ~ "^/var/lib/docker/" {print $2}' /proc/mounts 2>/dev/null | sort -r)
      sudo rm -rf /var/lib/docker /var/lib/containerd || warn "Could not fully remove /var/lib/docker (some mounts may remain)"
    fi
  fi

  # kubectl
  log "Removing kubectl"
  run_quiet sudo apt-get purge -y kubectl 2>/dev/null || true
  sudo rm -f /etc/apt/sources.list.d/kubernetes.list
  sudo rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg

  # kind
  log "Removing kind"
  sudo rm -f /usr/local/bin/kind

  # helm
  log "Removing helm"
  sudo rm -f /usr/local/bin/helm

  # Azure CLI
  log "Removing Azure CLI"
  run_quiet sudo apt-get purge -y azure-cli 2>/dev/null || true
  sudo rm -f /etc/apt/sources.list.d/azure-cli.list
  sudo rm -f /etc/apt/sources.list.d/azure-cli.sources
  sudo rm -f /etc/apt/keyrings/microsoft.gpg

  # GitHub CLI
  log "Removing GitHub CLI"
  run_quiet sudo apt-get purge -y gh 2>/dev/null || true
  sudo rm -f /etc/apt/sources.list.d/github-cli.list
  sudo rm -f /etc/apt/keyrings/githubcli-archive-keyring.gpg

  # VS Code extensions (Windows side)
  if has_cmd cmd.exe; then
    log "Removing VS Code extensions (Windows side)"
    local ext
    for ext in "${VSCODE_EXTENSIONS[@]}"; do
      cmd.exe /c "code --uninstall-extension $ext" 2>/dev/null || true
    done
  fi

  # GCM
  local gcm_helper
  gcm_helper="$(git config --global credential.helper 2>/dev/null || true)"
  if [[ "$gcm_helper" == *"git-credential-manager"* ]]; then
    log "Removing GCM configuration"
    git config --global --unset credential.helper 2>/dev/null || true
  fi

  # NOTE: symlink ($BIN_LINK) and cloned repository ($INSTALL_DIR) are
  # intentionally preserved by --tools / clean-soft so that the user can
  # re-provision with "dropwsl install". They are only removed on
  # --unregister / --purge (handled by the PowerShell uninstaller).

  # Clean orphan packages
  log "Cleaning orphan packages"
  run_quiet sudo apt-get autoremove -y

  log "Partial cleanup complete"
  echo
  echo "Tools removed. Distro, dropwsl and base packages remain intact."
  echo "Run 'dropwsl install' to re-provision."
  echo "Note: global Git settings (pull.ff, fetch.prune, etc.) are preserved."
  echo "  To remove: git config --global --unset pull.ff  (etc.)"
}
