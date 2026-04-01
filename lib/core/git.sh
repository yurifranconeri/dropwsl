#!/usr/bin/env bash
# lib/core/git.sh -- Configures GCM and global Git defaults.
# Requires: common.sh sourced (GIT_DEFAULTS)

[[ -n "${_GIT_SH_LOADED:-}" ]] && return 0
_GIT_SH_LOADED=1

# Configures the Windows Git Credential Manager (GCM) as credential.helper.
# Enables corporate SSO (Entra ID), GitHub Enterprise and Azure DevOps.
configure_gcm() {
  # Searches for GCM dynamically via Windows PATH, with fallback to default path
  local gcm_path=""
  local gcm_candidate
  gcm_candidate="$(cmd.exe /c "where git-credential-manager.exe" 2>/dev/null | head -n1 | tr -d '\r' || true)"
  if [[ -n "$gcm_candidate" ]]; then
    # Converts Windows path (C:\\...) to WSL (/mnt/c/...)
    gcm_path="$(wslpath -u "$gcm_candidate" 2>/dev/null || true)"
  fi
  if [[ -z "$gcm_path" ]] || [[ ! -f "$gcm_path" ]]; then
    gcm_path="/mnt/c/Program Files/Git/mingw64/bin/git-credential-manager.exe"
  fi

  if [[ ! -f "$gcm_path" ]]; then
    warn "Git for Windows not found -- GCM not configured."
    warn "Install Git for Windows (https://git-scm.com/download/win) for corporate SSO."
    return 0
  fi

  local current_helper
  current_helper="$(git config --global credential.helper 2>/dev/null || true)"

  if [[ "$current_helper" == *"git-credential-manager"* ]]; then
    # Detects path with spaces without literal quotes -- git does word-splitting and fails
    if [[ "$current_helper" == *" "* ]] && [[ "$current_helper" != \"* ]]; then
      log "GCM configured but without quotes (path with spaces) -- reconfiguring"
    else
      log "GCM already configured: ${current_helper}"
      return 0
    fi
  fi

  log "Configuring Windows Git Credential Manager (GCM)"
  # Path needs literal quotes in .gitconfig -- git does word-splitting when executing the helper
  git config --global credential.helper "\"$gcm_path\""
  log "GCM configured -- on next git operation, login opens in Windows browser"
}

# Configures global Git defaults from GIT_DEFAULTS (read from config.yaml).
configure_git_defaults() {
  log "Configuring global Git defaults"

  if ! has_cmd git; then
    warn "git not found -- defaults not configured"
    return 0
  fi

  local key
  for key in "${!GIT_DEFAULTS[@]}"; do
    git config --global "$key" "${GIT_DEFAULTS[$key]}" 2>/dev/null || true
  done

  # Build message with configured defaults
  local summary=""
  for key in "${!GIT_DEFAULTS[@]}"; do
    summary+="${key}=${GIT_DEFAULTS[$key]}, "
  done
  summary="${summary%, }"

  log "Git defaults configured (${summary})"
}
