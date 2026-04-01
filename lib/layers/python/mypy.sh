#!/usr/bin/env bash
# lib/layers/python/mypy.sh — Layer: mypy (type checking)
# Adds mypy with strict mode to the project.

[[ -n "${_MYPY_SH_LOADED:-}" ]] && return 0
_MYPY_SH_LOADED=1

_LAYER_PHASE="quality"
_LAYER_CONFLICTS=""
_LAYER_REQUIRES=""

apply_layer_mypy() {
  local project_path="$1"
  local devcontainer_dir="${4:-${project_path}/.devcontainer}"

  log "Applying layer: mypy (type checking)"

  local tpl_dir; tpl_dir="$(find_layer_templates_dir "python" "mypy")"

  # ---- requirements-dev.txt ----
  inject_fragment "${tpl_dir}/fragments/requirements-dev.txt" "${project_path}/requirements-dev.txt"

  # ---- pyproject.toml: [tool.mypy] section ----
  if [[ -f "${project_path}/pyproject.toml" ]]; then
    if ! grep -Fq '[tool.mypy]' "${project_path}/pyproject.toml"; then
      # Detect Python version from Dockerfile (source-of-truth)
      local py_version="3.12"
      if [[ -f "${devcontainer_dir}/Dockerfile" ]]; then
        local detected
        detected="$(sed -n 's/^FROM python:\([0-9]*\.[0-9]*\).*/\1/p' "${devcontainer_dir}/Dockerfile" | head -n1)"
        [[ -n "$detected" ]] && py_version="$detected"
      fi
      inject_fragment "${tpl_dir}/fragments/pyproject-mypy.toml" "${project_path}/pyproject.toml" "PY_VERSION=${py_version}"
    fi
  fi

  # ---- post-create.sh: mypy check before "Environment ready" ----
  if [[ -f "${devcontainer_dir}/post-create.sh" ]]; then
    if ! grep -q 'mypy' "${devcontainer_dir}/post-create.sh"; then
      if grep -q '==> Environment ready' "${devcontainer_dir}/post-create.sh"; then
        local pronto_line
        pronto_line="$(grep -Fn '==> Environment ready' "${devcontainer_dir}/post-create.sh" | head -n1 | cut -d: -f1)"
        if [[ -n "$pronto_line" ]]; then
          sed -i "$((pronto_line - 1))r ${tpl_dir}/fragments/post-create-mypy.sh" "${devcontainer_dir}/post-create.sh"
        fi
      else
        warn "Anchor 'Environment ready' not found in post-create.sh -- mypy check not injected"
      fi
    fi
  fi

  # Enable Pylance type checking in devcontainer.json
  local devcontainer="${devcontainer_dir}/devcontainer.json"
  if [[ -f "$devcontainer" ]]; then
    if ! grep -q 'typeCheckingMode' "$devcontainer"; then
      if grep -Fq '"python.testing.pytestEnabled"' "$devcontainer"; then
        sed -i '/"python\.testing\.pytestEnabled"/i\        "python.analysis.typeCheckingMode": "basic",' "$devcontainer"
      else
        warn "Anchor 'python.testing.pytestEnabled' not found in devcontainer.json -- typeCheckingMode not injected"
      fi
    fi
  fi

  echo "  Layer:    mypy (type checking)"
}
