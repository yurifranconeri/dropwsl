#!/usr/bin/env bash
# lib/core/helm.sh -- Installs Helm v3 using the official get-helm-3 script.
# Requires: common.sh sourced (HELM_VERSION)

[[ -n "${_HELM_SH_LOADED:-}" ]] && return 0
_HELM_SH_LOADED=1

install_helm() {
  if has_cmd helm; then
    log "helm already installed: $(helm version --short 2>/dev/null || true)"
    return 0
  fi
  log "Installing Helm ${HELM_VERSION} (official script)"
  local helm_tmp
  helm_tmp="$(make_temp)"
  curl_retry -fsSL -o "$helm_tmp" "https://raw.githubusercontent.com/helm/helm/${HELM_VERSION}/scripts/get-helm-3"
  # NOTE: official script executed as root. We check content ('HELM_INSTALL_DIR')
  # as a basic sanity check, but no checksum is available for the script itself.
  # Supply-chain risk accepted: official script hosted by the Helm project on GitHub.
  if ! grep -q 'HELM_INSTALL_DIR' "$helm_tmp" 2>/dev/null; then
    die "Downloaded Helm script appears corrupted or invalid"
  fi
  chmod +x "$helm_tmp"
  bash "$helm_tmp" --version "$HELM_VERSION"
}
