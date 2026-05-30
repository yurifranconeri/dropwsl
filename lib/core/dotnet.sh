#!/usr/bin/env bash
# lib/core/dotnet.sh — Installs .NET SDK via official Microsoft apt repository.
# Requires: common.sh sourced (DOTNET_VERSION)

[[ -n "${_DOTNET_SH_LOADED:-}" ]] && return 0
_DOTNET_SH_LOADED=1

install_dotnet() {
  if has_cmd dotnet; then
    log ".NET SDK already installed: $(dotnet --version 2>/dev/null || true)"
    return 0
  fi

  log "Installing .NET SDK ${DOTNET_VERSION} via Microsoft apt repository"
  get_distro_info

  local version_id
  version_id="$(sed -n 's/^VERSION_ID=//p' /etc/os-release | tr -d '"')"
  if [[ -z "$version_id" ]]; then
    die "Cannot detect VERSION_ID from /etc/os-release"
  fi

  local prod_deb_tmp
  prod_deb_tmp="$(make_temp)"
  curl_retry -fsSL -o "$prod_deb_tmp" \
    "https://packages.microsoft.com/config/${DISTRO_ID}/${version_id}/packages-microsoft-prod.deb"
  sudo dpkg -i "$prod_deb_tmp"

  run_quiet sudo apt-get update
  run_quiet sudo apt-get install -y "dotnet-sdk-${DOTNET_VERSION}"

  if ! has_cmd dotnet; then
    die_hint "dotnet command not found after install" \
      ".NET SDK package did not install correctly;PATH does not include dotnet" \
      "Check: dpkg -l 'dotnet-sdk-*';Run: dropwsl install" \
      "dotnet --version"
  fi
}
