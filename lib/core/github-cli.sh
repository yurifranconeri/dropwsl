#!/usr/bin/env bash
# lib/core/github-cli.sh -- Installs GitHub CLI (gh) via official apt repository.
# Requires: common.sh sourced

[[ -n "${_GITHUB_CLI_SH_LOADED:-}" ]] && return 0
_GITHUB_CLI_SH_LOADED=1

install_github-cli() {
  if has_cmd gh; then
    log "GitHub CLI (gh) already installed: $(gh --version | head -n 1 || true)"
    return 0
  fi

  log "Installing GitHub CLI (gh) via official repository"
  local keyring_tmp
  keyring_tmp="$(make_temp)"
  curl_retry -fsSL -o "$keyring_tmp" https://cli.github.com/packages/githubcli-archive-keyring.gpg
  # Binary GPG key copied directly (not ASCII-armored, no dearmor needed).
  # Supply-chain risk accepted: hosted by GitHub, same trust chain as the apt repository.
  sudo cp "$keyring_tmp" /etc/apt/keyrings/githubcli-archive-keyring.gpg
  sudo chmod a+r /etc/apt/keyrings/githubcli-archive-keyring.gpg

  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null

  run_quiet sudo apt-get update
  run_quiet sudo apt-get install -y gh
}
