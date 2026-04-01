#!/usr/bin/env bash
# lib/core/kind.sh -- Installs kind (Kubernetes in Docker).
# Requires: common.sh sourced (KIND_VERSION)

[[ -n "${_KIND_SH_LOADED:-}" ]] && return 0
_KIND_SH_LOADED=1

install_kind() {
  if has_cmd kind; then
    log "kind already installed: $(kind version || true)"
    return 0
  fi
  log "Installing kind ${KIND_VERSION} (Kubernetes local)"
  local arch
  case "$(uname -m)" in
    x86_64)  arch="amd64" ;;
    aarch64) arch="arm64" ;;
    *)       die "Architecture $(uname -m) not supported for kind." ;;
  esac
  local tmpfile checksum_file
  tmpfile="$(make_temp)"
  checksum_file="$(make_temp)"
  curl_retry -fLo "$tmpfile" "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-${arch}"
  curl_retry -fsSL -o "$checksum_file" "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-${arch}.sha256sum"

  local expected actual
  expected="$(awk '{print $1}' "$checksum_file")"
  actual="$(sha256sum "$tmpfile" | awk '{print $1}')"
  if [[ "$expected" != "$actual" ]]; then
    die_hint "kind: SHA256 checksum failed! Expected: ${expected}, got: ${actual}" \
      "Corrupted download;Proxy/firewall tampered with the binary;Possible man-in-the-middle attack" \
      "Retry (may be a transient network failure);If using corporate proxy, check it is not injecting certificates;Download manually from https://kind.sigs.k8s.io" \
      "sha256sum /usr/local/bin/kind"
  fi
  chmod +x "$tmpfile"
  sudo mv "$tmpfile" /usr/local/bin/kind
  log "kind ${KIND_VERSION} installed with verified checksum"
}
