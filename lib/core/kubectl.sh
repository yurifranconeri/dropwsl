#!/usr/bin/env bash
# lib/core/kubectl.sh -- Installs kubectl via official pkgs.k8s.io repository.
# Requires: common.sh sourced (KUBECTL_VERSION)

[[ -n "${_KUBECTL_SH_LOADED:-}" ]] && return 0
_KUBECTL_SH_LOADED=1

# Removes kubectl installed via snap, if any, to avoid conflict.
_remove_snap_kubectl_if_any() {
  if has_cmd snap; then
    if snap list 2>/dev/null | awk '{print $1}' | grep -qx kubectl; then
      log "Removing snap-installed kubectl (to avoid PATH conflict)"
      sudo snap remove kubectl || true
    fi
  fi
}

install_kubectl() {
  if has_cmd kubectl && kubectl version --client >/dev/null 2>&1; then
    log "kubectl already functional: $(command -v kubectl)"
    return 0
  fi

  _remove_snap_kubectl_if_any

  log "Installing kubectl via official repository (pkgs.k8s.io v${KUBECTL_VERSION})"
  local k8s_gpg_tmp
  k8s_gpg_tmp="$(make_temp)"
  curl_retry -fsSL -o "$k8s_gpg_tmp" "https://pkgs.k8s.io/core:/stable:/v${KUBECTL_VERSION}/deb/Release.key"
  sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg < "$k8s_gpg_tmp"
  sudo chmod a+r /etc/apt/keyrings/kubernetes-apt-keyring.gpg

  echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/v${KUBECTL_VERSION}/deb/ /" \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null

  run_quiet sudo apt-get update
  run_quiet sudo apt-get install -y kubectl
}
