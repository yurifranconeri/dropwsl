#!/usr/bin/env bash
# lib/layers/shared/trivy.sh — Layer: Trivy (vulnerability scanning)
# Injects Trivy extension into devcontainer.json and creates .trivyignore.
# Cross-language: works with any template.

[[ -n "${_TRIVY_SH_LOADED:-}" ]] && return 0
_TRIVY_SH_LOADED=1

_LAYER_PHASE="security"
_LAYER_CONFLICTS=""
_LAYER_REQUIRES=""

apply_layer_trivy() {
  local project_path="$1"
  local devcontainer_dir="${4:-${project_path}/.devcontainer}"

  log "Applying layer: trivy (vulnerability scanning)"

  # ---- Inject Trivy extension into devcontainer.json ----
  inject_vscode_extension "${devcontainer_dir}/devcontainer.json" "AquaSecurityOfficial.trivy-vulnerability-scanner"

  # ---- .trivyignore (no-clobber) ----
  local trivyignore="${project_path}/.trivyignore"
  if [[ ! -f "$trivyignore" ]]; then
    local tpl_dir; tpl_dir="$(find_layer_templates_dir "shared" "trivy")"
    render_template "$tpl_dir/templates/.trivyignore" "$trivyignore"
  fi

  echo "  Layer:    trivy (vulnerability scanning via VS Code)"
}
