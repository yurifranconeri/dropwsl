#!/usr/bin/env bash
# lib/core/vscode.sh -- Installs VS Code extensions on the Windows side.
# Requires: common.sh sourced (VSCODE_EXTENSIONS)

[[ -n "${_VSCODE_SH_LOADED:-}" ]] && return 0
_VSCODE_SH_LOADED=1

install_vscode_extensions() {
  if ! has_cmd cmd.exe; then
    warn "cmd.exe not found. Skipping VS Code extension installation."
    return 0
  fi

  if ! cmd.exe /c "code --version" >/dev/null 2>&1; then
    warn "VS Code (code) not found on Windows. Skipping extension installation."
    return 0
  fi

  log "Installing VS Code extensions (Windows side) via cmd.exe"
  local ext
  for ext in "${VSCODE_EXTENSIONS[@]}"; do
    local output
    output="$(cmd.exe /c "code --install-extension $ext" 2>&1 | tr -d '\r')" || true
    if [[ "$output" == *"successfully installed"* ]] || [[ "$output" == *"already installed"* ]]; then
      echo -e "  \033[32mOK\033[0m  - $ext"
    else
      warn "Failed to install extension: $ext"
      # Show code output for diagnostics (skip empty lines)
      local line
      while IFS= read -r line; do
        [[ -n "$line" ]] && echo "        $line" >&2
      done <<< "$output"
    fi
  done
}
