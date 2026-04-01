#!/usr/bin/env bash
# lib/layers/shared/semgrep.sh — Semgrep (multi-language SAST)
# Adds Semgrep CLI + VS Code extension + config rules.
# Cross-language: works with any template.

[[ -n "${_SEMGREP_SH_LOADED:-}" ]] && return 0
_SEMGREP_SH_LOADED=1

_LAYER_PHASE="security"
_LAYER_CONFLICTS=""
_LAYER_REQUIRES=""

apply_layer_semgrep() {
  local project_path="$1"
  local devcontainer_dir="${4:-${project_path}/.devcontainer}"

  log "Applying layer: semgrep (static code analysis)"

  local tpl_dir; tpl_dir="$(find_layer_templates_dir "shared" "semgrep")"

  # ---- .semgrep.yml (no-clobber) ----
  local semgrep_config="${project_path}/.semgrep.yml"
  if [[ ! -f "$semgrep_config" ]]; then
    render_template "$tpl_dir/templates/.semgrep.yml" "$semgrep_config"
  fi

  # ---- Inject Semgrep extension into devcontainer.json ----
  inject_vscode_extension "${devcontainer_dir}/devcontainer.json" "Semgrep.semgrep"

  # ---- Add semgrep to dev deps (if requirements-dev.txt exists) ----
  # Note: in shared/ to be cross-language, but Python deps are no-op for non-Python
  inject_fragment "${tpl_dir}/fragments/requirements-dev.txt" "${project_path}/requirements-dev.txt"

  echo "  Layer:    semgrep (SAST — static code analysis via VS Code + CLI)"
}
