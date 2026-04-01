#!/usr/bin/env bash
# tests/helpers/layer_test_helper.bash — Standard setup for layer tests
# Usage: load '../../helpers/layer_test_helper'
# Provides: setup_project_scaffold(), source_layer()

BATS_TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
REPO_ROOT="$(cd "$BATS_TEST_DIR" && while [[ ! -f dropwsl.sh ]] && [[ "$PWD" != "/" ]]; do cd ..; done; pwd)"

load "${REPO_ROOT}/tests/helpers/test_helper"
load "${REPO_ROOT}/tests/helpers/mock_commands"

# Source project modules (layers, scaffold, etc.)
unset _LAYERS_SH_LOADED _SCAFFOLD_SH_LOADED _NEW_SH_LOADED _WORKSPACE_SH_LOADED
source "${REPO_ROOT}/lib/project/layers.sh"
source "${REPO_ROOT}/lib/project/scaffold.sh"
source "${REPO_ROOT}/lib/project/new.sh"
source "${REPO_ROOT}/lib/project/workspace.sh"

# Creates full Python scaffold in $TEST_TEMP/project — returns path
# Mirrors what scaffold_devcontainer + new_project generate in real usage:
#   - Full .devcontainer/ from template (dev Dockerfile, post-create.sh with anchors, real devcontainer.json)
#   - Prod Dockerfile at project root
#   - Starter files (pyproject.toml, main.py, requirements, README, tests, dotfiles)
setup_project_scaffold() {
  local project="${TEST_TEMP}/project"
  local name="${1:-testapp}"
  mkdir -p "${project}/tests"

  local tpl_dir="${REPO_ROOT}/templates/devcontainer/python"

  # .devcontainer/ — copy entire template (dev Dockerfile, post-create.sh, devcontainer.json, pip.conf)
  cp -r "${tpl_dir}/.devcontainer" "${project}/.devcontainer"

  # Prod Dockerfile at root (layers like src, fastapi, uv modify this)
  cp "${tpl_dir}/Dockerfile" "${project}/"

  # Starter files
  cp "${tpl_dir}/pyproject.toml"       "${project}/"
  cp "${tpl_dir}/main.py"              "${project}/"
  cp "${tpl_dir}/requirements.txt"     "${project}/"
  cp "${tpl_dir}/requirements-dev.txt" "${project}/"
  [[ -f "${tpl_dir}/README.md" ]] && cp "${tpl_dir}/README.md" "${project}/"
  [[ -d "${tpl_dir}/tests" ]] && cp "${tpl_dir}/tests/"* "${project}/tests/" 2>/dev/null || true

  # Dotfiles
  for f in "${tpl_dir}"/.[!.]*; do
    [[ -e "$f" ]] && [[ ! -d "$f" ]] && cp "$f" "${project}/"
  done

  # Replace project name in pyproject.toml
  sed -i "s/^name = .*/name = \"${name}\"/" "${project}/pyproject.toml" 2>/dev/null || true

  echo "$project"
}

# Source the indicated layer (resets guard clause first)
source_layer() {
  local layer_path="$1"
  local guard_var
  guard_var="$(head -n3 "$layer_path" | grep -oP '_[A-Z_]+_LOADED' | head -n1)"
  [[ -n "$guard_var" ]] && unset "$guard_var"
  source "$layer_path"
}

# Validates valid JSON (uses python3 if available, otherwise basic grep)
assert_valid_json() {
  local file="$1"
  if command -v python3 >/dev/null 2>&1; then
    python3 -m json.tool < "$file" >/dev/null 2>&1
  else
    # Fallback: check that it starts with { and ends with }
    head -c1 "$file" | grep -q '{'
    tail -c2 "$file" | grep -q '}'
  fi
}

# Validates valid JSONC (strips // line comments before validation)
assert_valid_jsonc() {
  local file="$1"
  if command -v python3 >/dev/null 2>&1; then
    sed 's|^\s*//.*||' "$file" | python3 -m json.tool >/dev/null 2>&1
  else
    head -c1 "$file" | grep -q '{'
    tail -c2 "$file" | grep -q '}'
  fi
}

# Validates that file does not contain \r (CRLF)
assert_no_crlf() {
  local file="$1"
  ! grep -qP '\r' "$file"
}
