#!/usr/bin/env bash
# lib/core/nodejs.sh — Installs Node.js LTS via NodeSource apt repository.
# Requires: common.sh sourced (NODEJS_VERSION)

[[ -n "${_NODEJS_SH_LOADED:-}" ]] && return 0
_NODEJS_SH_LOADED=1

install_nodejs() {
  if has_cmd node; then
    log "Node.js already installed: $(node --version 2>/dev/null || true)"
    return 0
  fi

  log "Installing Node.js ${NODEJS_VERSION}.x LTS via NodeSource"
  get_distro_info

  # NodeSource GPG key
  local keyring="/etc/apt/keyrings/nodesource.gpg"
  sudo mkdir -p /etc/apt/keyrings
  local key_tmp
  key_tmp="$(make_temp)"
  curl_retry -fsSL -o "$key_tmp" "https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key"
  if ! gpg --dearmor -o - < "$key_tmp" | sudo tee "$keyring" >/dev/null; then
    die_hint "Failed to dearmor NodeSource GPG key" \
      "GPG not installed or broken;Corrupted key file;Network issue during download" \
      "Check: gpg --version;Retry: dropwsl install" \
      "gpg --dearmor < $key_tmp | file -"
  fi
  if [[ ! -s "$keyring" ]]; then
    die_hint "NodeSource GPG keyring is empty after dearmor" \
      "GPG produced no output;File permissions issue on ${keyring}" \
      "Check: ls -la ${keyring};Retry: dropwsl install" \
      "file $keyring"
  fi

  # NodeSource apt repository
  echo "deb [signed-by=${keyring}] https://deb.nodesource.com/node_${NODEJS_VERSION}.x nodistro main" \
    | sudo tee /etc/apt/sources.list.d/nodesource.list >/dev/null

  run_quiet sudo apt-get update
  run_quiet sudo apt-get install -y nodejs

  if ! has_cmd node; then
    die_hint "node command not found after install" \
      "NodeSource package did not install correctly;PATH does not include /usr/bin" \
      "Check: dpkg -l nodejs;Run: dropwsl install" \
      "node --version"
  fi
}
