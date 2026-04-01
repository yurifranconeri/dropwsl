#!/usr/bin/env bats
# tests/integration/combinations/test_combo_streamlit_postgres.bats

setup() {
  load '../../helpers/layer_test_helper'
  _common_setup
  PROJECT="$(setup_project_scaffold "testapp")"
  source_layer "${REPO_ROOT}/lib/layers/python/src.sh"
  source_layer "${REPO_ROOT}/lib/layers/python/streamlit.sh"
  source_layer "${REPO_ROOT}/lib/layers/python/postgres.sh"
}

teardown() {
  _common_teardown
}

@test "combo streamlit+postgres: streamlit com DB sync" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_streamlit "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_postgres "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"

  # Streamlit em main.py
  grep -Fq "streamlit" "${PROJECT}/src/testapp/main.py" || \
  grep -Fq "streamlit" "${PROJECT}/main.py" 2>/dev/null

  # Postgres sync (not async — no FastAPI)
  assert [ -d "${PROJECT}/src/testapp/db" ]
}

@test "combo streamlit+postgres: main.py preserves streamlit (SRP)" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_streamlit "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_postgres "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"

  # postgres should NOT replace main.py (streamlit already rewrote it)
  grep -Fq "import streamlit" "${PROJECT}/src/testapp/main.py"
  # MUST NOT contain standalone postgres (engine.execute)
  ! grep -q 'create_all\|engine.execute\|def main.*create' "${PROJECT}/src/testapp/main.py"
}
