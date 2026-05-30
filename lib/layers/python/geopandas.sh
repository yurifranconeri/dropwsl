#!/usr/bin/env bash
# lib/layers/python/geopandas.sh — Layer: GeoPandas (vector geoprocessing)
# Self-contained `geo/vector/` package with CLI (read/reproject/area for SHP/GeoJSON/GPKG/Parquet/ZIP-CAR).

[[ -n "${_GEOPANDAS_SH_LOADED:-}" ]] && return 0
_GEOPANDAS_SH_LOADED=1

_LAYER_PHASE="framework"
_LAYER_CONFLICTS=""
_LAYER_REQUIRES=""

apply_layer_geopandas() {
  local project_path="$1"
  local name="${2:-my-project}"
  # $3 = lang (unused), $4 = devcontainer_dir (unused — layer is self-contained)

  log "Applying layer: geopandas (vector geoprocessing)"

  local package_name; package_name="$(_to_package_name "$name")"
  _detect_python_layout "$project_path" "$package_name"
  local pkg_base="$_PKG_BASE"

  local tpl_dir; tpl_dir="$(find_layer_templates_dir "python" "geopandas")"

  # ---- requirements.txt ----
  inject_fragment "${tpl_dir}/fragments/requirements.txt" "${project_path}/requirements.txt"

  # ---- .gitignore: ignore data/ (raw CAR/DEM are heavy, keep out of VCS) ----
  if [[ -f "${project_path}/.gitignore" ]]; then
    inject_fragment "${tpl_dir}/fragments/gitignore" "${project_path}/.gitignore"
  fi

  # ---- Idempotency: if geo/vector/ already exists, skip code generation ----
  if [[ -d "${pkg_base}/geo/vector" ]]; then
    log "Directory geo/vector/ already exists -- skipping code generation"
    echo "  Layer:    geopandas (vector geoprocessing) [already applied]"
    return 0
  fi

  # ---- Create geo/ namespace + geo/vector/ package ----
  mkdir -p "${pkg_base}/geo/vector/data/sample"

  # geo/__init__.py — empty namespace marker (siblings: vector/, raster/, viz/, ...)
  if [[ ! -f "${pkg_base}/geo/__init__.py" ]]; then
    render_template "${tpl_dir}/templates/geo/__init__.py" "${pkg_base}/geo/__init__.py"
  fi

  # geo/vector/ source files
  render_template "${tpl_dir}/templates/geo/vector/__init__.py" "${pkg_base}/geo/vector/__init__.py"
  render_template "${tpl_dir}/templates/geo/vector/__main__.py" "${pkg_base}/geo/vector/__main__.py"
  render_template "${tpl_dir}/templates/geo/vector/io.py"       "${pkg_base}/geo/vector/io.py"
  render_template "${tpl_dir}/templates/geo/vector/crs.py"      "${pkg_base}/geo/vector/crs.py"
  render_template "${tpl_dir}/templates/geo/vector/ops.py"      "${pkg_base}/geo/vector/ops.py"
  render_template "${tpl_dir}/templates/geo/vector/_errors.py"  "${pkg_base}/geo/vector/_errors.py"
  render_template "${tpl_dir}/templates/geo/vector/README.md"   "${pkg_base}/geo/vector/README.md"

  # Bundled fixture — copy raw (no placeholder substitution; preserve byte-exact GeoJSON)
  cp -- "${tpl_dir}/templates/geo/vector/data/sample/brasil_regioes.geojson" \
        "${pkg_base}/geo/vector/data/sample/brasil_regioes.geojson"

  echo "  Layer:    geopandas (vector geoprocessing)"
}
