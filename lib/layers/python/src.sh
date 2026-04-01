#!/usr/bin/env bash
# lib/layers/python/src.sh — Layer: src layout (PEP 621)
# Reorganizes to src/{package}/ layout, adds CLI entry point.

[[ -n "${_SRC_SH_LOADED:-}" ]] && return 0
_SRC_SH_LOADED=1

_LAYER_PHASE="structure"
_LAYER_CONFLICTS=""
_LAYER_REQUIRES=""

apply_layer_src() {
  local project_path="$1"
  local name="$2"

  if [[ -z "$name" ]]; then
    die "Layer src requires project name (arg \$2 is empty)"
  fi

  local package_name; package_name="$(_to_package_name "$name")"

  log "Applying layer: src layout (package: ${package_name})"

  mkdir -p "${project_path}/src/${package_name}"

  if [[ -f "${project_path}/main.py" ]] && [[ ! -f "${project_path}/src/${package_name}/main.py" ]]; then
    mv "${project_path}/main.py" "${project_path}/src/${package_name}/main.py"
  fi

  if [[ ! -f "${project_path}/src/${package_name}/__init__.py" ]]; then
    local tpl_dir; tpl_dir="$(find_layer_templates_dir "python" "src")"
    cp "$tpl_dir/templates/__init__.py" "${project_path}/src/${package_name}/__init__.py"
  fi

  if [[ -f "${project_path}/pyproject.toml" ]]; then
    sed -i 's|pythonpath = \["\.\"]|pythonpath = ["src"]|g' "${project_path}/pyproject.toml"
    sed -i 's|source = \["\.\"]|source = ["src"]|g' "${project_path}/pyproject.toml"
    if ! grep -Fq '[project.scripts]' "${project_path}/pyproject.toml"; then
      local tpl_dir; tpl_dir="$(find_layer_templates_dir "python" "src")"
      local scripts_tmp; scripts_tmp="$(make_temp)"
      render_template "$tpl_dir/fragments/pyproject-scripts.toml" "$scripts_tmp" "NAME=${name}" "PACKAGE_NAME=${package_name}"
      cat "$scripts_tmp" >> "${project_path}/pyproject.toml"
    fi
  fi

  if [[ -f "${project_path}/tests/test_main.py" ]]; then
    local sed_safe_pkg; sed_safe_pkg="$(_sed_escape "$package_name")"
    sed -i "s|from main import main|from ${sed_safe_pkg}.main import main|g" "${project_path}/tests/test_main.py"
  fi

  if [[ -f "${project_path}/Dockerfile" ]]; then
    if ! grep -q 'COPY src/ src/' "${project_path}/Dockerfile"; then
      local tpl_dir; tpl_dir="$(find_layer_templates_dir "python" "src")"
      local src_copy_tmp; src_copy_tmp="$(make_temp)"
      cp "$tpl_dir/fragments/dockerfile-copy-src.txt" "$src_copy_tmp"
      local copy_line
      copy_line="$(grep -Fn 'COPY requirements.txt .' "${project_path}/Dockerfile" | head -n1 | cut -d: -f1)"
      if [[ -n "$copy_line" ]]; then
        sed -i "${copy_line}r ${src_copy_tmp}" "${project_path}/Dockerfile"
        sed -i "${copy_line}d" "${project_path}/Dockerfile"
      fi
    fi
    if ! grep -q 'pip install --no-deps' "${project_path}/Dockerfile"; then
      sed -i 's|pip install --no-cache-dir -r requirements.txt|pip install --no-cache-dir -r requirements.txt \&\& pip install --no-deps --no-cache-dir .|' "${project_path}/Dockerfile"
    fi
    local sed_safe_name; sed_safe_name="$(_sed_escape "$name")"
    sed -i "s|CMD \[\"python\", \"main.py\"\]|CMD [\"${sed_safe_name}\"]|" "${project_path}/Dockerfile"
  fi

  if [[ -f "${project_path}/README.md" ]]; then
    sed -i 's|├── main.py.*|├── src/              # Source code (src layout)|' "${project_path}/README.md"
    local sed_safe_name; sed_safe_name="$(_sed_escape "$name")"
    sed -i "s|python main.py|${sed_safe_name}|g" "${project_path}/README.md"
  fi

  echo "  Layer:    src (src/${package_name}/)"
}
