#!/usr/bin/env bats
# tests/integration/combinations/test_combo_streamlit_chat.bats
# Validates: src + streamlit + streamlit-chat combination.
# streamlit-chat (infra-inject phase) runs AFTER streamlit (framework),
# so it must correctly detect the Streamlit app and rewrite main.py with Chat UI.

setup() {
  load '../../helpers/layer_test_helper'
  _common_setup
  PROJECT="$(setup_project_scaffold "testapp")"
  source_layer "${REPO_ROOT}/lib/layers/python/src.sh"
  source_layer "${REPO_ROOT}/lib/layers/python/streamlit.sh"
  source_layer "${REPO_ROOT}/lib/layers/python/streamlit-chat.sh"
}

teardown() {
  _common_teardown
}

_apply_full_stack() {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_streamlit "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_streamlit_chat "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
}

# ── Core artifacts ────────────────────────────────────────────────

@test "combo streamlit-chat: all artifacts present" {
  _apply_full_stack
  assert [ -d "${PROJECT}/src/testapp/chat_ui" ]
  assert [ -f "${PROJECT}/src/testapp/chat_ui/__init__.py" ]
  assert [ -f "${PROJECT}/src/testapp/chat_ui/api.py" ]
}

@test "combo streamlit-chat: main.py has Chat UI (not showcase)" {
  _apply_full_stack
  grep -Fq "stream_message" "${PROJECT}/src/testapp/main.py"
  grep -Fq "st.chat_input" "${PROJECT}/src/testapp/main.py"
  # Showcase-specific content should be replaced
  ! grep -Fq 'st.slider("Slider"' "${PROJECT}/src/testapp/main.py"
}

@test "combo streamlit-chat: main.py uses bare import (no src prefix)" {
  _apply_full_stack
  grep -Fq "from chat_ui.api import" "${PROJECT}/src/testapp/main.py"
  ! grep -Fq "from testapp.chat_ui" "${PROJECT}/src/testapp/main.py"
}

@test "combo streamlit-chat: __init__.py uses relative import" {
  _apply_full_stack
  grep -Fq "from .api import" "${PROJECT}/src/testapp/chat_ui/__init__.py"
}

@test "combo streamlit-chat: .streamlit/config.toml from base layer" {
  _apply_full_stack
  assert [ -f "${PROJECT}/.streamlit/config.toml" ]
}

@test "combo streamlit-chat: requirements has both streamlit and requests" {
  _apply_full_stack
  grep -Fq "streamlit" "${PROJECT}/requirements.txt"
  grep -Fq "requests" "${PROJECT}/requirements.txt"
}

@test "combo streamlit-chat: Dockerfile CMD is streamlit run" {
  _apply_full_stack
  grep -Fq "streamlit" "${PROJECT}/Dockerfile"
  grep -Fq "8501" "${PROJECT}/Dockerfile"
}

@test "combo streamlit-chat: main.py has API Mode selectbox" {
  _apply_full_stack
  grep -Fq "API Mode" "${PROJECT}/src/testapp/main.py"
  grep -Fq "Chat Completions" "${PROJECT}/src/testapp/main.py"
}

@test "combo streamlit-chat: idempotent" {
  _apply_full_stack
  local snap1="${TEST_TEMP}/snap1"
  mkdir -p "$snap1"
  cp -a "${PROJECT}/src/testapp/chat_ui" "$snap1/chat_ui"

  _apply_full_stack
  diff -rq "$snap1/chat_ui" "${PROJECT}/src/testapp/chat_ui"
}
