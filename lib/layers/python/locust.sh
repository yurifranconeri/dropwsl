#!/usr/bin/env bash
# lib/layers/python/locust.sh — Layer: Locust (load testing)
# Adds generic locustfile.py, locust to dev-deps,
# and (if compose.yaml exists) a locust service with official image.

[[ -n "${_LOCUST_SH_LOADED:-}" ]] && return 0
_LOCUST_SH_LOADED=1

_LAYER_PHASE="test"
_LAYER_CONFLICTS=""
_LAYER_REQUIRES=""

_find_first_block_line_with_text() {
  local block="$1"
  local text="$2"

  printf '%s\n' "$block" | awk -v needle="$text" 'index($0, needle) { print NR; exit }'
}

apply_layer_locust() {
  local project_path="$1"
  local name="${2:-my-project}"

  log "Applying layer: locust (load testing)"

  local tpl_dir; tpl_dir="$(find_layer_templates_dir "python" "locust")"

  # ---- Dependencies: always dev-deps ----
  inject_fragment "${tpl_dir}/fragments/requirements-dev.txt" "${project_path}/requirements-dev.txt"

  # ---- locustfile.py (no-clobber) ----
  local locustfile="${project_path}/locustfile.py"
  if [[ ! -f "$locustfile" ]]; then
    render_template "$tpl_dir/templates/locustfile.py" "$locustfile"
  fi

  # ---- Compose: inject locust service (official image) ----
  _inject_locust_compose_service "$project_path" "$name" "$tpl_dir"

  # ---- .env.example: LOCUST_HOST ----
  _inject_locust_env_example "$project_path" "$tpl_dir"

  # ---- README.md — Load Test section ----
  _inject_locust_readme "$project_path" "$name"

  # ---- mypy override for locustfile (locust has no complete stubs) ----
  if [[ -f "${project_path}/pyproject.toml" ]] && grep -Fq '[tool.mypy]' "${project_path}/pyproject.toml"; then
    inject_fragment "${tpl_dir}/fragments/pyproject-locust-mypy.toml" "${project_path}/pyproject.toml"
  fi

  echo "  Layer:    locust (load testing)"
}

# ---------------------------------------------------------------------------
# Helpers internos
# ---------------------------------------------------------------------------

# Injects "locust" service into compose.yaml (if it exists).
# Uses official locustio/locust image, mounts locustfile.py, exposes 8089.
_inject_locust_compose_service() {
  local project_path="$1"
  local name="$2"
  local tpl_dir="$3"

  local compose_file="${project_path}/compose.yaml"
  [[ -f "$compose_file" ]] || return 0

  if [[ -n "${DROPWSL_WORKSPACE:-}" ]]; then
    _configure_workspace_locust_service "$compose_file" "$name" "$tpl_dir"
    return 0
  fi

  # Locustfile path relative to compose.yaml root
  local locustfile_rel="./locustfile.py"

  local service_block="    image: locustio/locust
    ports:
      - \"8089:8089\"
    volumes:
      - ${locustfile_rel}:/mnt/locust/locustfile.py
    environment:
      LOCUST_LOCUSTFILE: /mnt/locust/locustfile.py
      LOCUST_HOST: \${LOCUST_HOST:-http://localhost:8000}"

  inject_compose_service "$project_path" "locust" "$service_block" ""
}

  _configure_workspace_locust_service() {
  local compose_file="$1"
  local service_name="$2"
  local tpl_dir="$3"

  grep -Fq "  ${service_name}:" "$compose_file" || return 0

  local svc_line next_service_offset service_end block_excerpt
  svc_line="$(grep -Fn "  ${service_name}:" "$compose_file" | head -n1 | cut -d: -f1)"
  [[ -n "$svc_line" ]] || return 0

  next_service_offset="$(tail -n "+${svc_line}" "$compose_file" | grep -nE '^  [a-zA-Z0-9._-]+:' | sed -n '2p' | cut -d: -f1)"
  if [[ -n "$next_service_offset" ]]; then
    service_end=$((svc_line + next_service_offset - 2))
  else
    service_end="$(wc -l < "$compose_file")"
  fi
  block_excerpt="$(sed -n "${svc_line},${service_end}p" "$compose_file")"

  local port_line actual_line
  port_line="$(_find_first_block_line_with_text "$block_excerpt" ':8000"')"
  if [[ -n "$port_line" ]]; then
    actual_line=$((svc_line + port_line - 1))
    sed -i "${actual_line}s|:8000\"|:8089\"|" "$compose_file"
  fi

  local cmd_line
  cmd_line="$(_find_first_block_line_with_text "$block_excerpt" 'command: sleep infinity')"
  if [[ -n "$cmd_line" ]]; then
    actual_line=$((svc_line + cmd_line - 1))
    sed -i "${actual_line}s|command: sleep infinity|command: locust -f locustfile.py --web-host 0.0.0.0 --web-port 8089|" "$compose_file"
  fi

  block_excerpt="$(sed -n "${svc_line},${service_end}p" "$compose_file")"
  if ! printf '%s\n' "$block_excerpt" | grep -Fq 'LOCUST_HOST:'; then
    local env_line
    env_line="$(_find_first_block_line_with_text "$block_excerpt" '    environment:')"
    if [[ -n "$env_line" ]]; then
      actual_line=$((svc_line + env_line - 1))
      sed -i "${actual_line}s|    environment: {}|    environment:|" "$compose_file"
      sed -i "${actual_line}a\\      LOCUST_HOST: \${LOCUST_HOST:-http://target-service:8000}" "$compose_file"
    else
      port_line="$(_find_first_block_line_with_text "$block_excerpt" ':8089"')"
      [[ -n "$port_line" ]] || return 0
      actual_line=$((svc_line + port_line - 1))
      local env_fragment="${tpl_dir}/fragments/compose-workspace-environment.yaml"
      sed -i "${actual_line}r ${env_fragment}" "$compose_file"
    fi
  fi
}

# Injects LOCUST_HOST into .env.example (if it exists).
_inject_locust_env_example() {
  local project_path="$1"
  local tpl_dir="$2"

  local env_example="${project_path}/.env.example"
  [[ -f "$env_example" ]] || return 0

  local env_fragment="${tpl_dir}/fragments/env-example-locust.txt"
  if [[ -n "${DROPWSL_WORKSPACE:-}" ]]; then
    env_fragment="${tpl_dir}/fragments/env-example-locust-workspace.txt"
  fi

  inject_fragment "$env_fragment" "$env_example"
}

# Injects Load Test section into README.md (generic, no framework-awareness).
_inject_locust_readme() {
  local project_path="$1"
  local name="$2"

  local readme="${project_path}/README.md"
  [[ -f "$readme" ]] || return 0
  grep -q 'Load Test' "$readme" && return 0

  local load_test_section="## Load Test

\`\`\`bash
# Run Locust locally (web UI at http://localhost:8089)
locust

# Headless: 50 users, ramp-up 10/s, 30s duration
locust --headless -u 50 -r 10 -t 30s

# Point to another host
locust --host https://my-service.example.com
\`\`\`

> The \`locustfile.py\` in the project root defines the load scenarios.
> Configure the target host via \`LOCUST_HOST\` in \`.env\` or \`--host\` in the CLI.
> Docs: https://docs.locust.io
"

  # Insert before "## Docker" if it exists, otherwise append
  if grep -q '^## Docker' "$readme"; then
    local docker_line
    docker_line="$(grep -n '^## Docker' "$readme" | head -n1 | cut -d: -f1)"
    if [[ -n "$docker_line" ]]; then
      local tmp; tmp="$(make_temp)"
      head -n "$((docker_line - 1))" "$readme" > "$tmp"
      echo "$load_test_section" >> "$tmp"
      tail -n "+${docker_line}" "$readme" >> "$tmp"
      mv "$tmp" "$readme"
    else
      echo "$load_test_section" >> "$readme"
    fi
  else
    echo "$load_test_section" >> "$readme"
  fi
}
