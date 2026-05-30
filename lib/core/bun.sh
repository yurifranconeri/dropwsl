#!/usr/bin/env bash
# lib/core/bun.sh — Installs Bun runtime via official GitHub release.
# Requires: common.sh sourced (BUN_VERSION)

[[ -n "${_BUN_SH_LOADED:-}" ]] && return 0
_BUN_SH_LOADED=1

install_bun() {
  if has_cmd bun; then
    log "Bun already installed: $(bun --version 2>/dev/null || true)"
    return 0
  fi

  log "Installing Bun ${BUN_VERSION}"
  local arch
  case "$(uname -m)" in
    x86_64)  arch="x64" ;;
    aarch64) arch="aarch64" ;;
    *)       die "Architecture $(uname -m) not supported for Bun." ;;
  esac

  local zip_tmp checksum_file extract_dir
  zip_tmp="$(make_temp)"
  checksum_file="$(make_temp)"
  extract_dir="$(make_temp_dir)"

  local zip_name="bun-linux-${arch}.zip"
  curl_retry -fLo "$zip_tmp" \
    "https://github.com/oven-sh/bun/releases/download/bun-v${BUN_VERSION}/${zip_name}"
  curl_retry -fsSL -o "$checksum_file" \
    "https://github.com/oven-sh/bun/releases/download/bun-v${BUN_VERSION}/SHASUMS256.txt"

  local expected actual
  expected="$(grep -F " ${zip_name}" "$checksum_file" | head -n1 | awk '{print $1}')"
  actual="$(sha256sum "$zip_tmp" | awk '{print $1}')"
  if [[ -z "$expected" ]]; then
    die_hint "Bun: could not find checksum for ${zip_name} in SHASUMS256.txt" \
      "SHASUMS256.txt format changed;Download was corrupted" \
      "Retry: dropwsl install;Check release: https://github.com/oven-sh/bun/releases/tag/bun-v${BUN_VERSION}" \
      "curl -fsSL https://github.com/oven-sh/bun/releases/download/bun-v${BUN_VERSION}/SHASUMS256.txt"
  fi
  if [[ "$expected" != "$actual" ]]; then
    die_hint "Bun: SHA256 checksum failed! Expected: ${expected}, got: ${actual}" \
      "Corrupted download;Proxy/firewall tampered with the binary;Possible man-in-the-middle attack" \
      "Retry (may be a transient network failure);If using corporate proxy, check it is not injecting certificates;Download manually from https://github.com/oven-sh/bun/releases" \
      "sha256sum /usr/local/bin/bun"
  fi

  unzip -qo "$zip_tmp" -d "$extract_dir"

  local bun_bin="${extract_dir}/bun-linux-${arch}/bun"
  if [[ ! -f "$bun_bin" ]]; then
    die_hint "Bun binary not found in downloaded archive" \
      "Zip structure changed;Download was corrupted" \
      "Retry: dropwsl install;Check release: https://github.com/oven-sh/bun/releases/tag/bun-v${BUN_VERSION}" \
      "ls -la ${extract_dir}/"
  fi

  chmod +x "$bun_bin"
  sudo mv "$bun_bin" /usr/local/bin/bun

  if ! has_cmd bun; then
    die_hint "bun command not found after install" \
      "Binary was not placed in PATH;/usr/local/bin not in PATH" \
      "Check: ls -la /usr/local/bin/bun;Run: dropwsl install" \
      "bun --version"
  fi

  log "Bun ${BUN_VERSION} installed with verified checksum"
}
