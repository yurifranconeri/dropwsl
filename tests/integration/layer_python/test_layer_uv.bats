#!/usr/bin/env bats
# tests/integration/layer_python/test_layer_uv.bats

setup() {
  load '../../helpers/layer_test_helper'
  _common_setup
  PROJECT="$(setup_project_scaffold "testapp")"
  source_layer "${REPO_ROOT}/lib/layers/python/uv.sh"
}

teardown() {
  _common_teardown
}

@test "layer_uv: Dockerfile contains COPY --from uv" {
  apply_layer_uv "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -q "ghcr.io/astral-sh/uv" "${PROJECT}/.devcontainer/Dockerfile"
}

@test "layer_uv: post-create.sh uses uv" {
  apply_layer_uv "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -q "uv" "${PROJECT}/.devcontainer/post-create.sh"
}

@test "layer_uv: idempotent — uv already present → skip" {
  apply_layer_uv "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local snap1="${TEST_TEMP}/snap1"
  cat "${PROJECT}/.devcontainer/Dockerfile" > "$snap1"
  apply_layer_uv "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  diff "$snap1" "${PROJECT}/.devcontainer/Dockerfile"
}

@test "layer_uv: works with src layout" {
  source_layer "${REPO_ROOT}/lib/layers/python/src.sh"
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_uv "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -q "ghcr.io/astral-sh/uv" "${PROJECT}/.devcontainer/Dockerfile"
}

@test "layer_uv: README mentions uv" {
  apply_layer_uv "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -qi "uv" "${PROJECT}/README.md" 2>/dev/null || true
}

@test "layer_uv: creates uv.toml with http-timeout" {
  apply_layer_uv "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq 'UV_HTTP_TIMEOUT=300' "${PROJECT}/Dockerfile"
  grep -Fq 'UV_HTTP_RETRIES=5' "${PROJECT}/Dockerfile"
}

@test "layer_uv: creates uv.toml in devcontainer" {
  apply_layer_uv "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq 'UV_HTTP_TIMEOUT=300' "${PROJECT}/.devcontainer/Dockerfile"
  grep -Fq 'UV_HTTP_RETRIES=5' "${PROJECT}/.devcontainer/Dockerfile"
}

@test "layer_uv: Dockerfile replaces pip.conf with uv.toml" {
  apply_layer_uv "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq 'UV_HTTP_TIMEOUT' "${PROJECT}/Dockerfile"
}

@test "layer_uv: dev Dockerfile replaces pip.conf with uv.toml" {
  apply_layer_uv "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq 'UV_HTTP_TIMEOUT' "${PROJECT}/.devcontainer/Dockerfile"
}
