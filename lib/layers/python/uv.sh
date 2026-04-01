#!/usr/bin/env bash
# lib/layers/python/uv.sh — Layer: uv (replaces pip with uv)
# Replaces pip with uv in Dockerfiles and post-create.sh (installs 10-100x faster).

[[ -n "${_UV_SH_LOADED:-}" ]] && return 0
_UV_SH_LOADED=1

_LAYER_PHASE="tooling"
_LAYER_CONFLICTS=""
_LAYER_REQUIRES=""

apply_layer_uv() {
  local project_path="$1"
  local devcontainer_dir="${4:-${project_path}/.devcontainer}"

  local dockerfile="${project_path}/Dockerfile"
  local dev_dockerfile="${devcontainer_dir}/Dockerfile"
  local postcreate="${devcontainer_dir}/post-create.sh"
  local readme="${project_path}/README.md"

  # Idempotency: if uv already applied, skip
  # Idempotency: if uv already applied in any Dockerfile, skip
  if { [[ -f "$dockerfile" ]] && grep -Fq 'ghcr.io/astral-sh/uv' "$dockerfile"; } || \
     { [[ -f "$dev_dockerfile" ]] && grep -Fq 'ghcr.io/astral-sh/uv' "$dev_dockerfile"; }; then
    echo "  Layer:    uv (pip -> uv) [already applied]"
    return 0
  fi

  log "Applying layer: uv (replacing pip with uv)"

  # ---- uv timeout: ENV in Dockerfile (uv does not support timeout in uv.toml) ----
  # uv uses UV_HTTP_TIMEOUT (env var) to configure network timeout.
  # Equivalent to pip.conf timeout=300 -- same resilience pattern.

  # ---- Production Dockerfile ----
  if [[ -f "$dockerfile" ]]; then
    # Add uv binary to builder stage (multi-stage COPY, no install)
    sed -i '/^FROM.*AS builder/a\COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv' "$dockerfile"

    # python -m venv -> uv venv (creates clean venv without pip/setuptools)
    # Add VIRTUAL_ENV so uv pip install knows where to install
    local uv_venv_tmp; uv_venv_tmp="$(make_temp)"
    local tpl_dir_uv; tpl_dir_uv="$(find_layer_templates_dir "python" "uv")"
    cp "$tpl_dir_uv/fragments/dockerfile-uv-venv.txt" "$uv_venv_tmp"
    local venv_line
    venv_line="$(grep -Fn 'RUN python -m venv /opt/venv' "$dockerfile" | head -n1 | cut -d: -f1)"
    if [[ -n "$venv_line" ]]; then
      sed -i "${venv_line}r ${uv_venv_tmp}" "$dockerfile"
      sed -i "${venv_line}d" "$dockerfile"
    fi

    # Remove pip uninstall (uv venv is already clean by default)
    sed -i '/pip uninstall/d' "$dockerfile"

    # Remove continuation \ left dangling after pip uninstall removal
    sed -i '/^RUN.*pip install/ s/ *\\$//' "$dockerfile"

    # pip install → uv pip install (idempotent: normalize first to avoid double-prefix)
    sed -i 's/uv pip install/pip install/g' "$dockerfile"
    sed -i 's/pip install/uv pip install/g' "$dockerfile"

    # --no-cache-dir (pip) → --no-cache (uv)
    sed -i 's/--no-cache-dir/--no-cache/g' "$dockerfile"

    # uv ignores pip.conf — timeout and retries via ENV (parity with pip.conf)
    if ! grep -Fq 'UV_HTTP_TIMEOUT' "$dockerfile"; then
      sed -i '/^COPY --from=.*uv.*\/usr\/local\/bin\/uv/a\ENV UV_HTTP_TIMEOUT=300 UV_HTTP_RETRIES=5' "$dockerfile"
    fi
  fi

  # ---- Dev Container Dockerfile ----
  if [[ -f "$dev_dockerfile" ]]; then
    # Add uv binary before venv creation
    # COUPLING: anchors on the comment '# Venv at fixed path' in the template Dockerfile
    if ! grep -Fq 'astral-sh/uv' "$dev_dockerfile"; then
      sed -i '/^# Venv at fixed path/i\\COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv' "$dev_dockerfile"
    fi

    # python -m venv → uv venv
    sed -i 's/python -m venv \$VIRTUAL_ENV/uv venv $VIRTUAL_ENV/' "$dev_dockerfile"

    # pip install → uv pip install (idempotent: normalize first to avoid double-prefix)
    sed -i 's/uv pip install/pip install/g' "$dev_dockerfile"
    sed -i 's/pip install/uv pip install/g' "$dev_dockerfile"

    # Cache mount: pip → uv
    sed -i 's|/root/.cache/pip|/root/.cache/uv|' "$dev_dockerfile"

    # Update cache comment
    sed -i 's/pip reuses/uv reuses/' "$dev_dockerfile"

    # uv ignores pip.conf — timeout and retries via ENV (parity with pip.conf)
    if ! grep -Fq 'UV_HTTP_TIMEOUT' "$dev_dockerfile"; then
      sed -i '/^COPY --from=.*uv.*\/usr\/local\/bin\/uv/a\ENV UV_HTTP_TIMEOUT=300 UV_HTTP_RETRIES=5' "$dev_dockerfile"
    fi
  fi

  # ---- post-create.sh ----
  if [[ -f "$postcreate" ]]; then
    sed -i 's/uv pip install/pip install/g' "$postcreate"
    sed -i 's/pip install/uv pip install/g' "$postcreate"
  fi

  # ---- README.md ----
  if [[ -f "$readme" ]]; then
    sed -i 's/multi-stage build (no pip/multi-stage build with uv (no pip/' "$readme"
  fi

  # ---- requirements.txt (supply-chain comments) ----
  local reqfile="${project_path}/requirements.txt"
  if [[ -f "$reqfile" ]]; then
    sed -i 's/pip-compile/uv pip compile/g' "$reqfile"
    sed -i 's/uv pip install/pip install/g' "$reqfile"
    sed -i 's/pip install/uv pip install/g' "$reqfile"
  fi

  echo "  Layer:    uv (pip -> uv)"
}
