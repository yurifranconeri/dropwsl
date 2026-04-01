#!/usr/bin/env bash
# lib/layers/shared/gitleaks.sh — Layer: Gitleaks (secret scanning)
# Adds pre-commit hook with Gitleaks to block commits containing secrets.
# Cross-language: works with any template.

[[ -n "${_GITLEAKS_SH_LOADED:-}" ]] && return 0
_GITLEAKS_SH_LOADED=1

_LAYER_PHASE="security"
_LAYER_CONFLICTS=""
_LAYER_REQUIRES=""

apply_layer_gitleaks() {
  local project_path="$1"
  local devcontainer_dir="${4:-${project_path}/.devcontainer}"
  local gitleaks_version="${GITLEAKS_VERSION:-v8.21.2}"

  log "Applying layer: gitleaks (secret scanning)"

  local tpl_dir; tpl_dir="$(find_layer_templates_dir "shared" "gitleaks")"

  # ---- .pre-commit-config.yaml (no-clobber) ----
  local precommit_file="${project_path}/.pre-commit-config.yaml"
  if [[ ! -f "$precommit_file" ]]; then
    render_template "$tpl_dir/templates/.pre-commit-config.yaml" "$precommit_file" "GITLEAKS_VERSION=${gitleaks_version}"
  else
    # File exists -- inject Gitleaks hook if not already present
    if ! grep -q 'gitleaks' "$precommit_file"; then
      local hook_tmp; hook_tmp="$(make_temp)"
      render_template "$tpl_dir/fragments/pre-commit-gitleaks-hook.yaml" "$hook_tmp" "GITLEAKS_VERSION=${gitleaks_version}"
      cat "$hook_tmp" >> "$precommit_file"
    fi
  fi

  # ---- .gitleaks.toml (no-clobber) — config to suppress false positives ----
  local gitleaks_config="${project_path}/.gitleaks.toml"
  if [[ ! -f "$gitleaks_config" ]]; then
    render_template "$tpl_dir/templates/.gitleaks.toml" "$gitleaks_config"
  fi

  # ---- Add pre-commit to dev deps (if requirements-dev.txt exists) ----
  inject_fragment "${tpl_dir}/fragments/requirements-dev.txt" "${project_path}/requirements-dev.txt"

  # ---- Configure git hooks path and install pre-commit in post-create.sh ----
  if [[ -f "${devcontainer_dir}/post-create.sh" ]]; then
    if ! grep -q 'pre-commit install' "${devcontainer_dir}/post-create.sh"; then
      # Insert before the last line of post-create.sh (normally the final echo)
      local pcsh="${devcontainer_dir}/post-create.sh"
      local tmp; tmp="$(make_temp)"
      head -n -1 "$pcsh" > "$tmp"
      cat "${tpl_dir}/fragments/post-create-gitleaks.sh" >> "$tmp"
      tail -n 1 "$pcsh" >> "$tmp"
      mv "$tmp" "$pcsh"
    fi
  fi

  echo "  Layer:    gitleaks (secret scanning via pre-commit)"
}
