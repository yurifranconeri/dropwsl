#!/usr/bin/env bats
# tests/integration/layer_python/test_layer_streamlit.bats

setup() {
  load '../../helpers/layer_test_helper'
  _common_setup
  PROJECT="$(setup_project_scaffold "testapp")"
  source_layer "${REPO_ROOT}/lib/layers/python/streamlit.sh"
}

teardown() {
  _common_teardown
}

@test "layer_streamlit: main.py contains import streamlit" {
  apply_layer_streamlit "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "streamlit" "${PROJECT}/main.py"
}

@test "layer_streamlit: creates .streamlit/config.toml" {
  apply_layer_streamlit "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -f "${PROJECT}/.streamlit/config.toml" ]
}

@test "layer_streamlit: requirements.txt contains streamlit" {
  apply_layer_streamlit "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "streamlit" "${PROJECT}/requirements.txt"
}

@test "layer_streamlit: port 8501 configured" {
  apply_layer_streamlit "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -q "8501" "${PROJECT}/.streamlit/config.toml"
}

@test "layer_streamlit: idempotent" {
  apply_layer_streamlit "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local count_before
  count_before=$(grep -c "streamlit" "${PROJECT}/main.py" || true)
  apply_layer_streamlit "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local count_after
  count_after=$(grep -c "streamlit" "${PROJECT}/main.py" || true)
  assert [ "$count_before" -eq "$count_after" ]
}

@test "layer_streamlit: README Docker section uses port 8501" {
  apply_layer_streamlit "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq 'docker run -p 8501:8501' "${PROJECT}/README.md"
  ! grep -Fq 'docker run -p 8000:8000' "${PROJECT}/README.md"
}

@test "layer_streamlit: config.toml sets fileWatcherType=auto" {
  apply_layer_streamlit "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq 'fileWatcherType = "auto"' "${PROJECT}/.streamlit/config.toml"
}

@test "layer_streamlit: config.toml defines [theme.sidebar] to silence >=1.50 warnings" {
  apply_layer_streamlit "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq '[theme.sidebar]' "${PROJECT}/.streamlit/config.toml"
  grep -Fq 'primaryColor' "${PROJECT}/.streamlit/config.toml"
}

@test "layer_streamlit: .gitignore ignores .streamlit/secrets.toml" {
  apply_layer_streamlit "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq '.streamlit/secrets.toml' "${PROJECT}/.gitignore"
}

@test "layer_streamlit: .gitignore secrets entry is idempotent across re-applications" {
  apply_layer_streamlit "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_streamlit "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local count
  count=$(grep -cF '.streamlit/secrets.toml' "${PROJECT}/.gitignore")
  assert [ "$count" -eq 1 ]
}

@test "layer_streamlit: AppTest timeout >= 30s to absorb cold-start under load" {
  apply_layer_streamlit "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  # The default 10s was too tight on fresh post-create.sh (editable install
  # + uv sync + heavy imports), causing flaky `AppTest script run timed out`.
  grep -Fq '_APP_TEST_TIMEOUT = 30' "${PROJECT}/tests/test_main.py"
  ! grep -Eq 'at\.run\(timeout=10\)' "${PROJECT}/tests/test_main.py"
}
