#!/usr/bin/env bash
# lib/core/azure-cli.sh — Installs Azure CLI via official Microsoft apt repository.
# Requires: common.sh sourced

[[ -n "${_AZURE_CLI_SH_LOADED:-}" ]] && return 0
_AZURE_CLI_SH_LOADED=1

install_azure-cli() {
  if has_cmd az; then
    log "Azure CLI already installed: $(az --version 2>/dev/null | head -n 1 || true)"
    return 0
  fi
  log "Installing Azure CLI via official apt repository"
  get_distro_info

  local az_gpg_tmp
  az_gpg_tmp="$(make_temp)"
  curl_retry -fsSL -o "$az_gpg_tmp" https://packages.microsoft.com/keys/microsoft.asc
  sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/microsoft.gpg < "$az_gpg_tmp"
  sudo chmod a+r /etc/apt/keyrings/microsoft.gpg

  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft.gpg] \
https://packages.microsoft.com/repos/azure-cli/ ${DISTRO_CODENAME} main" \
    | sudo tee /etc/apt/sources.list.d/azure-cli.list >/dev/null

  run_quiet sudo apt-get update
  run_quiet sudo apt-get install -y azure-cli
}
