#!/usr/bin/env bats
# tests/integration/layer_python/test_layer_geopandas.bats

setup() {
  load '../../helpers/layer_test_helper'
  _common_setup
  PROJECT="$(setup_project_scaffold "testapp")"
  source_layer "${REPO_ROOT}/lib/layers/python/geopandas.sh"
}

teardown() {
  _common_teardown
}

# ── Package layout (flat) ────────────────────────────────────────

@test "layer_geopandas: creates geo/vector/ in flat layout" {
  apply_layer_geopandas "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -d "${PROJECT}/geo/vector" ]
  assert [ -f "${PROJECT}/geo/__init__.py" ]
  assert [ -f "${PROJECT}/geo/vector/__init__.py" ]
  assert [ -f "${PROJECT}/geo/vector/__main__.py" ]
  assert [ -f "${PROJECT}/geo/vector/io.py" ]
  assert [ -f "${PROJECT}/geo/vector/crs.py" ]
  assert [ -f "${PROJECT}/geo/vector/ops.py" ]
  assert [ -f "${PROJECT}/geo/vector/_errors.py" ]
  assert [ -f "${PROJECT}/geo/vector/README.md" ]
}

@test "layer_geopandas: bundled fixture is present and valid GeoJSON" {
  apply_layer_geopandas "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local fixture="${PROJECT}/geo/vector/data/sample/brasil_regioes.geojson"
  assert [ -f "$fixture" ]
  assert_valid_json "$fixture"
  grep -Fq 'EPSG::4674' "$fixture"
  grep -Fq '"FeatureCollection"' "$fixture"
}

# ── Package layout (src) ─────────────────────────────────────────

@test "layer_geopandas: creates geo/vector/ in src layout" {
  source_layer "${REPO_ROOT}/lib/layers/python/src.sh"
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_geopandas "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -d "${PROJECT}/src/testapp/geo/vector" ]
  assert [ -f "${PROJECT}/src/testapp/geo/vector/__main__.py" ]
  assert [ -f "${PROJECT}/src/testapp/geo/vector/data/sample/brasil_regioes.geojson" ]
}

# ── requirements & gitignore ────────────────────────────────────

@test "layer_geopandas: requirements.txt contains geopandas/pyogrio/shapely/pyproj" {
  apply_layer_geopandas "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "geopandas>=1.0" "${PROJECT}/requirements.txt"
  grep -Fq "pyogrio>=0.9"   "${PROJECT}/requirements.txt"
  grep -Fq "shapely>=2.0"   "${PROJECT}/requirements.txt"
  grep -Fq "pyproj>=3.6"    "${PROJECT}/requirements.txt"
}

@test "layer_geopandas: .gitignore contains data/" {
  apply_layer_geopandas "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fxq "data/" "${PROJECT}/.gitignore"
}

# ── Non-intrusive (does not touch user code) ────────────────────

@test "layer_geopandas: main.py is unchanged" {
  local before; before="$(md5sum "${PROJECT}/main.py" | cut -d' ' -f1)"
  apply_layer_geopandas "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local after;  after="$(md5sum  "${PROJECT}/main.py" | cut -d' ' -f1)"
  [[ "$before" == "$after" ]]
}

@test "layer_geopandas: does not create or modify compose.yaml" {
  apply_layer_geopandas "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  ! [ -f "${PROJECT}/compose.yaml" ]
}

@test "layer_geopandas: does not modify .env.example if present" {
  # Scaffold may copy .env.example from base — layer must not touch it.
  if [[ -f "${PROJECT}/.env.example" ]]; then
    local before; before="$(md5sum "${PROJECT}/.env.example" | cut -d' ' -f1)"
    apply_layer_geopandas "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
    local after;  after="$(md5sum  "${PROJECT}/.env.example" | cut -d' ' -f1)"
    [[ "$before" == "$after" ]]
  else
    apply_layer_geopandas "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
    ! [ -f "${PROJECT}/.env.example" ]
  fi
}

@test "layer_geopandas: devcontainer.json is unchanged" {
  local before; before="$(md5sum "${PROJECT}/.devcontainer/devcontainer.json" | cut -d' ' -f1)"
  apply_layer_geopandas "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local after;  after="$(md5sum  "${PROJECT}/.devcontainer/devcontainer.json" | cut -d' ' -f1)"
  [[ "$before" == "$after" ]]
}

# ── Idempotency ────────────────────────────────────────────────

@test "layer_geopandas: idempotent on second apply" {
  apply_layer_geopandas "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local snap1="${TEST_TEMP}/snap1"
  find "${PROJECT}/geo" -type f | sort | xargs md5sum > "$snap1"
  apply_layer_geopandas "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local snap2="${TEST_TEMP}/snap2"
  find "${PROJECT}/geo" -type f | sort | xargs md5sum > "$snap2"
  diff "$snap1" "$snap2"
}

@test "layer_geopandas: idempotent — requirements.txt has each dep exactly once" {
  apply_layer_geopandas "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_geopandas "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  [[ "$(grep -c '^geopandas>=1.0$' "${PROJECT}/requirements.txt")" -eq 1 ]]
  [[ "$(grep -c '^pyogrio>=0.9$'   "${PROJECT}/requirements.txt")" -eq 1 ]]
}

@test "layer_geopandas: idempotent — .gitignore has data/ exactly once" {
  apply_layer_geopandas "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_geopandas "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  [[ "$(grep -cFx 'data/' "${PROJECT}/.gitignore")" -eq 1 ]]
}

# ── File hygiene ───────────────────────────────────────────────

@test "layer_geopandas: no CRLF in generated python files" {
  apply_layer_geopandas "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  ! grep -rlP '\r' "${PROJECT}/geo/" --include='*.py'
}

@test "layer_geopandas: __main__.py is syntactically valid Python" {
  apply_layer_geopandas "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  if command -v python3 >/dev/null 2>&1; then
    python3 -m py_compile "${PROJECT}/geo/vector/__main__.py"
    python3 -m py_compile "${PROJECT}/geo/vector/io.py"
    python3 -m py_compile "${PROJECT}/geo/vector/crs.py"
    python3 -m py_compile "${PROJECT}/geo/vector/ops.py"
    python3 -m py_compile "${PROJECT}/geo/vector/__init__.py"
    python3 -m py_compile "${PROJECT}/geo/vector/_errors.py"
  else
    skip "python3 not available"
  fi
}
