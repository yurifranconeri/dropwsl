#!/usr/bin/env bash
# lib/layers/shared/compose.sh — Layer: Docker Compose
# Generates compose.yaml skeleton, .env.example and README section.
# Cross-language: works with any template.

[[ -n "${_COMPOSE_SH_LOADED:-}" ]] && return 0
_COMPOSE_SH_LOADED=1

_LAYER_PHASE="structure"
_LAYER_CONFLICTS=""
_LAYER_REQUIRES=""

apply_layer_compose() {
  local project_path="$1"
  local devcontainer_dir="${4:-${project_path}/.devcontainer}"
  local name="${2:-my-project}"
  local workspace_mode=false
  [[ -n "${DROPWSL_WORKSPACE:-}" ]] && workspace_mode=true

  log "Applying layer: compose (local infrastructure)"

  local net_name="${name}-net"
  local tpl_dir; tpl_dir="$(find_layer_templates_dir "shared" "compose")"

  # ---- compose.yaml (no-clobber) ----
  local compose_file="${project_path}/compose.yaml"
  if [[ ! -f "$compose_file" ]]; then
    if $workspace_mode; then
      die "Workspace compose.yaml missing at ${compose_file}"
    fi
    render_template "$tpl_dir/templates/compose.yaml" "$compose_file" "NET_NAME=${net_name}"
  fi

  # ---- Local infra marker (service intent, not workspace structure) ----
  ensure_env_example "$project_path"
  local env_example="${project_path}/.env.example"
  inject_fragment "${tpl_dir}/fragments/local-infra.env" "$env_example"

  if $workspace_mode; then
    echo "  Layer:    compose (local infrastructure)"
    return 0
  fi

  # ---- Dev Container: join compose network ----
  # Pre-creates the network and joins the dev container to it so compose
  # service hostnames (postgres, redis) resolve inside the dev container.
  local devcontainer="${devcontainer_dir}/devcontainer.json"
  if [[ -f "$devcontainer" ]] && ! grep -Fq 'initializeCommand' "$devcontainer"; then
    local anchor_line
    anchor_line="$(grep -Fn '"updateRemoteUserUID"' "$devcontainer" | head -n1 | cut -d: -f1)"
    if [[ -n "$anchor_line" ]]; then
      local net_inject_tmp; net_inject_tmp="$(make_temp)"
      render_template "$tpl_dir/fragments/devcontainer-network.json" "$net_inject_tmp" "NET_NAME=${net_name}"
      sed -i "${anchor_line}r ${net_inject_tmp}" "$devcontainer"
    fi
  fi

  # ---- README.md — Local infrastructure section ----
  local readme="${project_path}/README.md"
  if [[ -f "$readme" ]] && ! grep -Fq 'Local Infrastructure' "$readme"; then
    local infra_section="## Local Infrastructure

\`\`\`bash
# Start services (database, cache, etc.)
docker compose up -d

# View logs
docker compose logs -f

# Stop and remove volumes (full reset)
docker compose down -v
\`\`\`

> Services defined in \`compose.yaml\`. Variables in \`.env\` (copy from \`.env.example\`).
"
    if grep -q '^## Docker' "$readme"; then
      local docker_line
      docker_line="$(grep -n '^## Docker' "$readme" | head -n1 | cut -d: -f1)"
      local tmp
      tmp="$(make_temp)"
      head -n "$((docker_line - 1))" "$readme" > "$tmp"
      echo "$infra_section" >> "$tmp"
      tail -n "+${docker_line}" "$readme" >> "$tmp"
      mv "$tmp" "$readme"
    else
      echo "$infra_section" >> "$readme"
    fi

    # Update structure tree -- add compose.yaml
    if grep -Fq 'Project Structure' "$readme" && ! grep -Fq '# Docker Compose' "$readme"; then
      sed -i '/Production image/a\├── compose.yaml          # Docker Compose (local services)' "$readme"
    fi
  fi

  echo "  Layer:    compose (compose.yaml + .env.example)"
}
