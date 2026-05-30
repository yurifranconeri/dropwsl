#!/usr/bin/env bash
# lib/core/pac-cli.sh — Installs Power Platform CLI (pac) via .NET global tool.
# Requires: common.sh sourced (PAC_CLI_VERSION), dotnet installed

[[ -n "${_PAC_CLI_SH_LOADED:-}" ]] && return 0
_PAC_CLI_SH_LOADED=1

install_pac-cli() {
  if has_cmd pac; then
    log "PAC CLI already installed: $(pac --version 2>/dev/null | head -n2 | tail -n1 || true)"
    return 0
  fi

  if ! has_cmd dotnet; then
    die_hint "PAC CLI requires .NET SDK but 'dotnet' was not found" \
      ".NET SDK is not installed;core.dotnet.enabled is set to false in config.yaml" \
      "Enable .NET SDK: set core.dotnet.enabled to true in config.yaml;Run: dropwsl install" \
      "dotnet --version"
  fi

  log "Installing Power Platform CLI (pac) ${PAC_CLI_VERSION} via .NET global tool"
  log "Downloading NuGet package (~102 MB) -- this may take a minute"
  # NuGet package signing: .NET SDK verifies the package signature automatically.
  # Microsoft.PowerApps.CLI.Tool has NuGet prefix reservation (only Microsoft can publish).
  # Supply-chain risk mitigated by: version pinning + NuGet signature verification + prefix reservation.
  # DOTNET_NOLOGO + DOTNET_CLI_TELEMETRY_OPTOUT: suppress first-run experience and telemetry notice
  # that can hang or delay the first dotnet command after a fresh SDK install.
  DOTNET_NOLOGO=1 DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    dotnet tool install --global Microsoft.PowerApps.CLI.Tool \
      --version "${PAC_CLI_VERSION}" --verbosity normal

  # Ensure ~/.dotnet/tools is in PATH for this session
  local dotnet_tools="${HOME}/.dotnet/tools"
  if [[ ":${PATH}:" != *":${dotnet_tools}:"* ]]; then
    export PATH="${dotnet_tools}:${PATH}"
  fi

  # Persist PATH for future sessions
  local bashrc="${HOME}/.bashrc"
  if ! grep -qF '.dotnet/tools' "$bashrc" 2>/dev/null; then
    echo '' >> "$bashrc"
    echo '# .NET global tools (added by dropwsl)' >> "$bashrc"
    echo 'export PATH="$HOME/.dotnet/tools:$PATH"' >> "$bashrc"
  fi

  if ! has_cmd pac; then
    die_hint "pac command not found after install" \
      "dotnet tool install succeeded but pac is not in PATH;~/.dotnet/tools not in PATH" \
      "Check: ls ~/.dotnet/tools/pac;Run: export PATH=\"\$HOME/.dotnet/tools:\$PATH\"" \
      "pac --version"
  fi
}
