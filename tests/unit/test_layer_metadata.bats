#!/usr/bin/env bats
# tests/unit/test_layer_metadata.bats — Tests for declarative layer metadata
# Validates: _read_layer_metadata(), PHASE_ORDER, metadata in all layer files,
# ordering by phase, conflicts and generic dependencies.

setup() {
  load '../helpers/test_helper'
  _common_setup
  unset _LAYERS_SH_LOADED
  source "${REPO_ROOT}/lib/project/layers.sh"
}

teardown() {
  _common_teardown
}

# ── _read_layer_metadata ──────────────────────────────────────────

@test "_read_layer_metadata: reads phase from layer file" {
  local f="${REPO_ROOT}/lib/layers/python/fastapi.sh"
  _read_layer_metadata "$f"
  [[ "$_LAYER_PHASE" == "framework" ]]
}

@test "_read_layer_metadata: reads conflicts from layer file" {
  local f="${REPO_ROOT}/lib/layers/python/fastapi.sh"
  _read_layer_metadata "$f"
  [[ "$_LAYER_CONFLICTS" == "streamlit" ]]
}

@test "_read_layer_metadata: reads requires from layer file" {
  local f="${REPO_ROOT}/lib/layers/python/testcontainers.sh"
  _read_layer_metadata "$f"
  [[ "$_LAYER_REQUIRES" == "postgres" ]]
}

@test "_read_layer_metadata: layer without metadata → default tooling" {
  local tmp="${TEST_TEMP}/fake_layer.sh"
  cat > "$tmp" <<'EOF'
#!/usr/bin/env bash
[[ -n "${_FAKE_LOADED:-}" ]] && return 0
_FAKE_LOADED=1
apply_layer_fake() { :; }
EOF
  _read_layer_metadata "$tmp"
  [[ "$_LAYER_PHASE" == "tooling" ]]
  [[ "$_LAYER_CONFLICTS" == "" ]]
  [[ "$_LAYER_REQUIRES" == "" ]]
}

# ── All layers have metadata ──────────────────────────────────────

@test "metadata: all 22 layers declare _LAYER_PHASE" {
  local missing=()
  local f layer
  for f in "${REPO_ROOT}"/lib/layers/python/*.sh "${REPO_ROOT}"/lib/layers/shared/*.sh; do
    [[ -f "$f" ]] || continue
    layer="$(basename "$f" .sh)"
    # agent-helpers is not a layer
    [[ "$layer" == "agent-helpers" ]] && continue
    grep -q '^apply_layer_' "$f" || continue
    if ! grep -q '^_LAYER_PHASE=' "$f"; then
      missing+=("$layer")
    fi
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "Layers without _LAYER_PHASE: ${missing[*]}" >&2
    return 1
  fi
}

@test "metadata: declared phases are valid (exist in PHASE_ORDER)" {
  local invalid=()
  local f layer phase
  for f in "${REPO_ROOT}"/lib/layers/python/*.sh "${REPO_ROOT}"/lib/layers/shared/*.sh; do
    [[ -f "$f" ]] || continue
    layer="$(basename "$f" .sh)"
    [[ "$layer" == "agent-helpers" ]] && continue
    grep -q '^apply_layer_' "$f" || continue
    _read_layer_metadata "$f"
    phase="$_LAYER_PHASE"
    local found=false
    local p
    for p in "${PHASE_ORDER[@]}"; do
      [[ "$p" == "$phase" ]] && found=true && break
    done
    if ! $found; then
      invalid+=("${layer}=${phase}")
    fi
  done
  if [[ ${#invalid[@]} -gt 0 ]]; then
    echo "Layers with invalid phase: ${invalid[*]}" >&2
    return 1
  fi
}

# ── Ordering by phase ───────────────────────────────────────────

@test "metadata: src (structure) before fastapi (framework)" {
  # Verify that ordering respects phases
  local src_phase fastapi_phase
  _read_layer_metadata "${REPO_ROOT}/lib/layers/python/src.sh"
  src_phase="$_LAYER_PHASE"
  _read_layer_metadata "${REPO_ROOT}/lib/layers/python/fastapi.sh"
  fastapi_phase="$_LAYER_PHASE"
  [[ "$src_phase" == "structure" ]]
  [[ "$fastapi_phase" == "framework" ]]
  # structure (index 0) < framework (index 1) em PHASE_ORDER
}

@test "metadata: uv (tooling) after fastapi (framework)" {
  _read_layer_metadata "${REPO_ROOT}/lib/layers/python/uv.sh"
  local uv_phase="$_LAYER_PHASE"
  _read_layer_metadata "${REPO_ROOT}/lib/layers/python/fastapi.sh"
  local fastapi_phase="$_LAYER_PHASE"
  [[ "$uv_phase" == "tooling" ]]
  [[ "$fastapi_phase" == "framework" ]]
}

@test "metadata: compose (structure) before postgres/redis (infra/infra-inject)" {
  _read_layer_metadata "${REPO_ROOT}/lib/layers/shared/compose.sh"
  [[ "$_LAYER_PHASE" == "structure" ]]
  _read_layer_metadata "${REPO_ROOT}/lib/layers/python/postgres.sh"
  [[ "$_LAYER_PHASE" == "infra" ]]
  _read_layer_metadata "${REPO_ROOT}/lib/layers/python/redis.sh"
  [[ "$_LAYER_PHASE" == "infra-inject" ]]
  # structure (index 0) < infra (index 3) < infra-inject (index 4) em PHASE_ORDER
}

@test "metadata: agents (agents) is the last phase" {
  _read_layer_metadata "${REPO_ROOT}/lib/layers/shared/agent-developer.sh"
  [[ "$_LAYER_PHASE" == "agents" ]]
  # agents is the last in PHASE_ORDER
  local last="${PHASE_ORDER[${#PHASE_ORDER[@]}-1]}"
  [[ "$last" == "agents" ]]
}

# ── Invariante: consumers after producers ─────────────────────────
# Layers that check for compose.yaml (consumers) must be in a phase
# that comes AFTER the compose layer's phase (producer).
# This prevents the bug where postgres/redis run before compose.

@test "metadata: compose.yaml consumers are in phase after compose producer" {
  # Build phase index lookup
  local -A phase_index=()
  local i
  for i in "${!PHASE_ORDER[@]}"; do
    phase_index["${PHASE_ORDER[$i]}"]="$i"
  done

  # Compose is the producer — get its phase index
  _read_layer_metadata "${REPO_ROOT}/lib/layers/shared/compose.sh"
  local producer_idx="${phase_index[$_LAYER_PHASE]}"

  # Find all layers that grep for compose.yaml (consumers)
  local violations=()
  local f layer
  for f in "${REPO_ROOT}"/lib/layers/python/*.sh "${REPO_ROOT}"/lib/layers/shared/*.sh; do
    [[ -f "$f" ]] || continue
    layer="$(basename "$f" .sh)"
    [[ "$layer" == "compose" || "$layer" == "agent-helpers" ]] && continue
    grep -q '^apply_layer_' "$f" || continue
    # Does this layer check for compose.yaml?
    if grep -q 'compose\.yaml' "$f"; then
      _read_layer_metadata "$f"
      local consumer_idx="${phase_index[$_LAYER_PHASE]:-999}"
      if (( consumer_idx <= producer_idx )); then
        violations+=("${layer} (phase=${_LAYER_PHASE}, idx=${consumer_idx}) <= compose (phase=structure, idx=${producer_idx})")
      fi
    fi
  done
  if [[ ${#violations[@]} -gt 0 ]]; then
    echo "Layers that consume compose.yaml but run in same/earlier phase:" >&2
    printf '  %s\n' "${violations[@]}" >&2
    return 1
  fi
}

@test "metadata: redis (infra-inject) runs after postgres (infra)" {
  local -A phase_index=()
  local i
  for i in "${!PHASE_ORDER[@]}"; do
    phase_index["${PHASE_ORDER[$i]}"]="$i"
  done

  _read_layer_metadata "${REPO_ROOT}/lib/layers/python/postgres.sh"
  local pg_idx="${phase_index[$_LAYER_PHASE]}"
  _read_layer_metadata "${REPO_ROOT}/lib/layers/python/redis.sh"
  local redis_idx="${phase_index[$_LAYER_PHASE]}"
  (( redis_idx > pg_idx ))
}

# ── Declarative conflicts ────────────────────────────────────────

@test "metadata: fastapi declares conflict with streamlit" {
  _read_layer_metadata "${REPO_ROOT}/lib/layers/python/fastapi.sh"
  [[ "$_LAYER_CONFLICTS" == *"streamlit"* ]]
}

@test "metadata: streamlit declares conflict with fastapi" {
  _read_layer_metadata "${REPO_ROOT}/lib/layers/python/streamlit.sh"
  [[ "$_LAYER_CONFLICTS" == *"fastapi"* ]]
}

# ── Declarative dependencies ─────────────────────────────────────

@test "metadata: testcontainers declares requires postgres" {
  _read_layer_metadata "${REPO_ROOT}/lib/layers/python/testcontainers.sh"
  [[ "$_LAYER_REQUIRES" == *"postgres"* ]]
}

@test "metadata: compose has no requires" {
  _read_layer_metadata "${REPO_ROOT}/lib/layers/shared/compose.sh"
  [[ -z "$_LAYER_REQUIRES" ]]
}

# ── PHASE_ORDER ───────────────────────────────────────────────────

@test "PHASE_ORDER: contains 10 phases" {
  [[ ${#PHASE_ORDER[@]} -eq 10 ]]
}

@test "PHASE_ORDER: structure is first, agents is last" {
  [[ "${PHASE_ORDER[0]}" == "structure" ]]
  [[ "${PHASE_ORDER[${#PHASE_ORDER[@]}-1]}" == "agents" ]]
}
