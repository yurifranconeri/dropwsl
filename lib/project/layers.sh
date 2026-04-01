#!/usr/bin/env bash
# lib/project/layers.sh -- Layer orchestrator (auto-discovery by filesystem).
# Requires: common.sh sourced
# Layers are discovered from lib/layers/<lang>/*.sh and lib/layers/shared/*.sh

[[ -n "${_LAYERS_SH_LOADED:-}" ]] && return 0
_LAYERS_SH_LOADED=1

# Base directory for layers (relative to SCRIPT_DIR, defined in dropwsl.sh)
LAYERS_DIR="${SCRIPT_DIR}/lib/layers"

# Lists all available layers with descriptions
list_layers() {
  echo -e "\nAvailable layers (--with):\n"
  
  if [[ ! -d "$LAYERS_DIR" ]]; then
    echo "  No layers found in $LAYERS_DIR."
    return 0
  fi

  local lang dir f layer desc

  # Categorize: lang-specific, shared (non-agent), agents
  local -a categories=()
  local -A cat_files=()

  for dir in "$LAYERS_DIR"/*/; do
    [[ -d "$dir" ]] || continue
    lang="$(basename "$dir")"

    for f in "$dir"*.sh; do
      [[ -f "$f" ]] || continue
      grep -q '^apply_layer_' "$f" || continue
      layer="$(basename "$f" .sh)"

      local cat
      if [[ "$layer" == agent-* ]]; then
        cat="agents"
      elif [[ "$lang" == "shared" ]]; then
        cat="shared"
      else
        cat="$lang"
      fi

      # Track unique categories in order
      if [[ -z "${cat_files[$cat]+x}" ]]; then
        categories+=("$cat")
        cat_files[$cat]=""
      fi
      cat_files[$cat]+="$f"$'\n'
    done
  done

  for cat in "${categories[@]}"; do
    echo -e "  \033[1;36m${cat}\033[0m:"
    while IFS= read -r f; do
      [[ -z "$f" ]] && continue
      layer="$(basename "$f" .sh)"

      # Extract description: line 2-5, match em-dash, strip prefix "Layer: "
      desc="$(sed -n '2,5{ /—/{ s/^.*— *//; p; q; } }' "$f")"
      desc="${desc#Layer: }"
      if [[ -z "$desc" ]]; then
        desc="(no description)"
      fi
      
      printf "    %-18s %s\n" "$layer" "$desc"
    done <<< "${cat_files[$cat]}"
    echo ""
  done
}

# Execution phases -- layers declare _LAYER_PHASE and are ordered by this table.
# Ties in the same phase: user's --with order.
PHASE_ORDER=("structure" "framework" "quality" "infra" "infra-inject" "test" "tooling" "security" "devtools" "agents")

# Reads declarative metadata from a layer file via grep (without sourcing -- avoids guard clause).
# Populates variables: _LAYER_PHASE, _LAYER_CONFLICTS, _LAYER_REQUIRES
_read_layer_metadata() {
  local file="$1"
  _LAYER_PHASE="$(grep -m1 '^_LAYER_PHASE=' "$file" 2>/dev/null | cut -d'"' -f2)" || true
  _LAYER_CONFLICTS="$(grep -m1 '^_LAYER_CONFLICTS=' "$file" 2>/dev/null | cut -d'"' -f2)" || true
  _LAYER_REQUIRES="$(grep -m1 '^_LAYER_REQUIRES=' "$file" 2>/dev/null | cut -d'"' -f2)" || true
  # Default: layers without _LAYER_PHASE are treated as "tooling"
  if [[ -z "$_LAYER_PHASE" ]]; then
    _LAYER_PHASE="tooling"
  fi
}

# Returns the .sh path of a layer for a given language.
# Priority: layers/<lang>/<layer>.sh -> layers/shared/<layer>.sh
resolve_layer_file() {
  local layer="$1" lang="$2"

  local lang_file="${LAYERS_DIR}/${lang}/${layer}.sh"
  [[ -f "$lang_file" ]] && echo "$lang_file" && return 0

  local shared_file="${LAYERS_DIR}/shared/${layer}.sh"
  [[ -f "$shared_file" ]] && echo "$shared_file" && return 0

  # Layer exists but not for this language?
  if compgen -G "${LAYERS_DIR}/*/${layer}.sh" >/dev/null 2>&1; then
    local supported
    supported="$(for f in "${LAYERS_DIR}"/*/"${layer}.sh"; do basename "$(dirname "$f")"; done | grep -v '^shared$' | paste -sd', ')"
    if [[ -z "$supported" ]]; then
      supported="shared (cross-language)"
    fi
    die "Layer '${layer}' does not support '${lang}'. Available for: ${supported}"
  fi

  die "Unknown layer: '${layer}'. Use: --with $(list_available_layers "$lang" | paste -sd',')"
}

# Lists available layers for a given language.
list_available_layers() {
  local lang="$1"
  local -a layers=()

  local f
  for f in "${LAYERS_DIR}/${lang}"/*.sh; do
    [[ -f "$f" ]] || continue
    local layer_name
    layer_name="$(basename "$f" .sh)"
    grep -q '^apply_layer_' "$f" || continue
    layers+=("$layer_name")
  done
  for f in "${LAYERS_DIR}/shared"/*.sh; do
    [[ -f "$f" ]] || continue
    local layer_name
    layer_name="$(basename "$f" .sh)"
    grep -q '^apply_layer_' "$f" || continue
    layers+=("$layer_name")
  done

  printf '%s\n' "${layers[@]}" | sort -u
}

# Validates layers without applying (fail-fast before creating the project).
# Reads declarative metadata (_LAYER_CONFLICTS, _LAYER_REQUIRES) from each layer file.
validate_layers() {
  local layers_str="$1"
  local lang="${2:-python}"

  [[ -z "$layers_str" ]] && return 0

  local IFS=','
  set -f
  local -a requested_layers
  read -ra requested_layers <<< "$layers_str"
  set +f
  IFS=$' \t\n'

  # 1. Resolve all files (fail-fast if layer does not exist)
  local layer layer_file
  local -A layer_files=()
  for layer in "${requested_layers[@]}"; do
    layer="${layer// /}"
    [[ -z "$layer" ]] && continue
    layer_file="$(resolve_layer_file "$layer" "$lang")" || exit $?
    layer_files["$layer"]="$layer_file"
  done

  # 2. Read metadata from each layer via grep (without sourcing)
  local -A requested_set=()
  local -A conflicts=() requires=()
  for layer in "${!layer_files[@]}"; do
    requested_set["$layer"]=1
    _read_layer_metadata "${layer_files[$layer]}"
    conflicts["$layer"]="$_LAYER_CONFLICTS"
    requires["$layer"]="$_LAYER_REQUIRES"
  done

  # 3. Validate conflicts (generic -- reads from each layer)
  for layer in "${!conflicts[@]}"; do
    [[ -z "${conflicts[$layer]}" ]] && continue
    local IFS=','
    set -f
    local c
    for c in ${conflicts[$layer]}; do
      c="${c// /}"
      if [[ -n "${requested_set[$c]:-}" ]]; then
        die "Layers '${layer}' and '${c}' are mutually exclusive. In workspace mode, use separate --service."
      fi
    done
    set +f
    IFS=$' \t\n'
  done

  # 4. Validate dependencies (generic -- reads from each layer)
  for layer in "${!requires[@]}"; do
    [[ -z "${requires[$layer]}" ]] && continue
    local IFS=','
    set -f
    local r
    for r in ${requires[$layer]}; do
      r="${r// /}"
      if [[ -z "${requested_set[$r]:-}" ]]; then
        die "Layer '${layer}' requires '${r}'. Use: --with ${r},${layer}"
      fi
    done
    set +f
    IFS=$' \t\n'
  done
}

# Validates and applies --with layers.
apply_layers() {
  local layers_str="$1"
  local project_path="$2"
  local name="$3"
  local lang="${4:-python}"
  local devcontainer_dir="${5:-${project_path}/.devcontainer}"

  [[ -z "$layers_str" ]] && return 0

  # Parse CSV
  local IFS=','
  set -f
  local -a requested_layers
  read -ra requested_layers <<< "$layers_str"
  set +f
  IFS=$' \t\n'

  # Validate all before applying any
  local layer layer_file
  local -A layer_files=()
  for layer in "${requested_layers[@]}"; do
    layer="${layer// /}"
    layer_file="$(resolve_layer_file "$layer" "$lang")" || exit $?
    layer_files["$layer"]="$layer_file"
  done

  # Read _LAYER_PHASE from each layer via grep (without sourcing)
  local -A layer_phases=()
  for layer in "${!layer_files[@]}"; do
    _read_layer_metadata "${layer_files[$layer]}"
    layer_phases["$layer"]="$_LAYER_PHASE"
  done

  # Sort by phase priority, ties keep --with order from user
  local -a ordered=()
  local -A seen=()
  local ph
  for ph in "${PHASE_ORDER[@]}"; do
    for layer in "${requested_layers[@]}"; do
      layer="${layer// /}"
      [[ -z "$layer" ]] && continue
      if [[ "${layer_phases[$layer]:-}" == "$ph" ]] && [[ -z "${seen[$layer]:-}" ]]; then
        ordered+=("$layer")
        seen["$layer"]=1
      fi
    done
  done
  # Layers with unknown phase: append in user order
  for layer in "${requested_layers[@]}"; do
    layer="${layer// /}"
    [[ -z "$layer" ]] && continue
    if [[ -z "${seen[$layer]:-}" ]]; then
      ordered+=("$layer")
      seen["$layer"]=1
    fi
  done

  # Source and apply each layer
  for layer in "${ordered[@]}"; do
    local file="${layer_files[$layer]}"
    source "$file"

    local func_name="apply_layer_${layer//-/_}"
    if declare -F "$func_name" >/dev/null 2>&1; then
      "$func_name" "$project_path" "$name" "$lang" "$devcontainer_dir"
    else
      die "Layer '${layer}' loaded from '${file}' but function '${func_name}' not found."
    fi
  done

}
