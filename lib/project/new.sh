#!/usr/bin/env bash
# lib/project/new.sh -- New project creation.
# Requires: common.sh, project/scaffold.sh, project/layers.sh sourced

[[ -n "${_NEW_SH_LOADED:-}" ]] && return 0
_NEW_SH_LOADED=1

# Merges user layers with DEFAULT_LAYERS (config.yaml), deduplicating.
# Returns CSV via stdout.
_merge_default_layers() {
  local user_csv="$1"
  if [[ "$NO_DEFAULTS" == true ]] || (( ${#DEFAULT_LAYERS[@]} == 0 )); then
    echo "$user_csv"
    return 0
  fi
  local IFS=','
  set -f
  local -a merged=()
  [[ -n "$user_csv" ]] && read -ra merged <<< "$user_csv"
  local dl ul already
  for dl in "${DEFAULT_LAYERS[@]}"; do
    already=false
    for ul in "${merged[@]}"; do
      [[ "${ul// /}" == "$dl" ]] && already=true && break
    done
    [[ "$already" == false ]] && merged+=("$dl")
  done
  local csv
  csv="$(printf '%s,' "${merged[@]}")"
  set +f
  echo "${csv%,}"
}

# Creates a new project in ~/projects/<name>.
new_project() {
  local name="${1:-}"
  local lang="${2:-}"
  local with_layers="${3:-}"
  local service="${4:-}"

  if [[ -z "$name" ]]; then
    echo "Usage: dropwsl new <project-name> <language> [--with layer1,layer2]" >&2
    echo "       dropwsl new <workspace> --service <svc> <language> [--with ...]" >&2
    die "E.g.: dropwsl new my-service python --with src"
  fi

  if [[ "$name" =~ [^a-zA-Z0-9._-] ]] || [[ "$name" == ..* ]] || [[ "$name" =~ ^[.]+$ ]] || [[ "$name" == -* ]] || [[ "$name" == .* ]]; then
    die "Invalid project name: '${name}'. Use only letters, numbers, '-', '_' and '.' (cannot start with '-' or '.')"
  fi

  if [[ -z "$lang" ]]; then
    list_available_langs
    echo "Missing language. Available:"
    echo
    local l
    for l in "${AVAILABLE_LANGS[@]}"; do
      echo "  $l"
    done
    echo
    die "Usage: dropwsl new $name <language>"
  fi

  local project_path
  local devcontainer_dir
  local workspace_mode=false
  local workspace_path=""
  local pkg_name="$name"

  if [[ -n "$service" ]]; then
    # ---- Workspace mode (multi-service) ----
    workspace_mode=true
    workspace_path="${PROJECTS_DIR}/${name}"
    project_path="${workspace_path}/services/${service}"
    devcontainer_dir="${workspace_path}/.devcontainer/${service}"
    pkg_name="$service"

    # Validate service name
    if [[ "$service" =~ [^a-zA-Z0-9._-] ]] || [[ "$service" == -* ]] || [[ "$service" == .* ]]; then
      die "Invalid service name: '$service'. Use only letters, numbers, '-', '_' and '.'"
    fi
  else
    # ---- Standalone mode (default) ----
    project_path="${PROJECTS_DIR}/${name}"
    devcontainer_dir="${project_path}/.devcontainer"
  fi

  # Validate layers BEFORE creating any directory (fail-fast)
  local all_layers
  all_layers="$(_merge_default_layers "$with_layers")"

  validate_layers "$all_layers" "$lang"

  if [[ -d "$project_path" ]]; then
    if [[ "$ASSUME_YES" != true ]]; then
      warn "Directory already exists: ${project_path}"
      local confirm
      read -rp "Continue anyway? (y/N) " confirm
      [[ "$confirm" =~ ^[yY]$ ]] || { echo "Cancelled."; return 0; }
    fi
  fi

  # ---- Workspace: inicializa esqueleto (idempotente) ----
  # Calculate port BEFORE mkdir (otherwise count includes the service being created)
  local host_port=""
  if $workspace_mode; then
    workspace_init "$workspace_path" "$name"
    host_port="$(_workspace_next_port "$workspace_path")"
    log "Creating service '${service}' in workspace '${name}'"
  else
    log "Creating project '${name}' with template '${lang}'"
  fi

  mkdir -p "$project_path"

  # Git init only in standalone (workspace already has git at root)
  if ! $workspace_mode && [[ ! -d "${project_path}/.git" ]]; then
    run_quiet git -C "$project_path" init
  fi

  pushd "$project_path" > /dev/null
  scaffold_devcontainer "$lang" true
  popd > /dev/null

  # Workspace mode: scaffold copies .devcontainer/ to the service -- we need to remove it
  # since in workspace mode the devcontainer is in .devcontainer/<service>/ at workspace root
  if $workspace_mode; then
    rm -rf "${project_path}/.devcontainer"
    workspace_devcontainer "$workspace_path" "$service" "$name" "$lang"
    workspace_compose_service "$workspace_path" "$service" "$name" "$host_port"
    # Copy compose.yaml from workspace to service dir -- layers modify here
    # After apply_layers, move back to the workspace
    cp "${workspace_path}/compose.yaml" "${project_path}/compose.yaml"
  fi

  local sed_safe_name; sed_safe_name="$(_sed_escape "$pkg_name")"

  if [[ -f "${project_path}/pyproject.toml" ]]; then
    sed -i "s|name = \"my-project\"|name = \"${sed_safe_name}\"|g" "${project_path}/pyproject.toml"
  fi

  if [[ -f "${project_path}/README.md" ]]; then
    sed -i "s|my-project|${sed_safe_name}|g" "${project_path}/README.md"
  fi

  # Reuse layers already merged during validation (avoids duplicate call)
  with_layers="$all_layers"

  # Workspace: signal workspace mode to layers (skip app service, .env merge)
  if $workspace_mode; then
    DROPWSL_WORKSPACE="$workspace_path"
  fi

  apply_layers "$with_layers" "$project_path" "$pkg_name" "$lang" "$devcontainer_dir"

  # Clear flag
  DROPWSL_WORKSPACE=""

  # Workspace: move compose.yaml modified by layers back to the root
  if $workspace_mode && [[ -f "${project_path}/compose.yaml" ]]; then
    mv "${project_path}/compose.yaml" "${workspace_path}/compose.yaml"
  fi

  # Workspace: merge service .env.example into workspace root
  if $workspace_mode && [[ -f "${project_path}/.env.example" ]]; then
    local ws_env="${workspace_path}/.env.example"
    local svc_env="${project_path}/.env.example"
    # Append lines that do not exist in the workspace
    while IFS= read -r line || [[ -n "$line" ]]; do
      [[ -z "$line" ]] && continue
      [[ "$line" == \#* ]] && continue
      grep -Fq "$line" "$ws_env" 2>/dev/null || echo "$line" >> "$ws_env"
    done < "$svc_env"
  fi

  echo
  if $workspace_mode; then
    echo "Summary:"
    echo "  Workspace: ${workspace_path}"
    echo "  Service:   ${service} (services/${service}/)"
    echo "  Template:  ${lang}"
    [[ -n "$with_layers" ]] && echo "  Layers:    ${with_layers}" || true
  else
    echo "Summary:"
    echo "  Path:      ${project_path}"
    echo "  Git:      initialized"
    echo "  Template: ${lang} (.devcontainer/ copied)"
    [[ -n "$with_layers" ]] && echo "  Layers:   ${with_layers}" || true
  fi

  local open_path
  if $workspace_mode; then
    open_path="$workspace_path"
  else
    open_path="$project_path"
  fi

  if has_cmd code; then
    echo
    log "Opening in VS Code..."
    # code CLI from WSL already injects --remote automatically;
    # passing --remote explicitly causes "Option 'remote' is defined more than once".
    if code --new-window "$open_path"; then
      echo
      echo "  >>> VS Code will suggest 'Reopen in Container' automatically."
      echo "  >>> If not: Ctrl+Shift+P > Dev Containers: Reopen in Container"
    else
      warn "Failed to open VS Code (try again with: code ${open_path})"
    fi
  else
    echo
    echo "To open in VS Code:"
    echo "  code ${open_path}"
    echo "  O VS Code vai sugerir \"Reopen in Container\" automaticamente."
  fi
}
