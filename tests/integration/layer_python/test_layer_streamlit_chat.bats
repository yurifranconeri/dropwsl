#!/usr/bin/env bats
# tests/integration/layer_python/test_layer_streamlit_chat.bats

setup() {
  load '../../helpers/layer_test_helper'
  _common_setup
  PROJECT="$(setup_project_scaffold "testapp")"
  source_layer "${REPO_ROOT}/lib/layers/python/src.sh"
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  source_layer "${REPO_ROOT}/lib/layers/python/streamlit.sh"
  apply_layer_streamlit "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  source_layer "${REPO_ROOT}/lib/layers/python/streamlit-chat.sh"
}

teardown() {
  _common_teardown
}

# ── Core artifacts ────────────────────────────────────────────────

@test "layer_streamlit_chat: creates chat_ui/ package" {
  apply_layer_streamlit_chat "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -d "${PROJECT}/src/testapp/chat_ui" ]
  assert [ -f "${PROJECT}/src/testapp/chat_ui/__init__.py" ]
  assert [ -f "${PROJECT}/src/testapp/chat_ui/api.py" ]
}

@test "layer_streamlit_chat: main.py has Chat UI" {
  apply_layer_streamlit_chat "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "stream_message" "${PROJECT}/src/testapp/main.py"
  grep -Fq "st.chat_input" "${PROJECT}/src/testapp/main.py"
}

@test "layer_streamlit_chat: .env.example contains CHAT_API_URL" {
  apply_layer_streamlit_chat "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "CHAT_API_URL" "${PROJECT}/.env.example"
}

@test "layer_streamlit_chat: requirements has requests" {
  apply_layer_streamlit_chat "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "requests" "${PROJECT}/requirements.txt"
}

@test "layer_streamlit_chat: README has Chat UI section" {
  apply_layer_streamlit_chat "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "Chat UI" "${PROJECT}/README.md"
}

@test "layer_streamlit_chat: test file has chat_input test" {
  apply_layer_streamlit_chat "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "chat_input" "${PROJECT}/tests/test_main.py"
}

@test "layer_streamlit_chat: main.py has API Mode selectbox" {
  apply_layer_streamlit_chat "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "API Mode" "${PROJECT}/src/testapp/main.py"
  grep -Fq "Chat Completions" "${PROJECT}/src/testapp/main.py"
}

# ── Import paths (src layout) ────────────────────────────────────
# Streamlit adds the script directory to sys.path, so bare imports work.
# No src prefix applied — "from chat_ui.api import" is correct.

@test "layer_streamlit_chat: main.py uses bare chat_ui import (no src prefix)" {
  apply_layer_streamlit_chat "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "from chat_ui.api import" "${PROJECT}/src/testapp/main.py"
  # Must NOT have package prefix
  ! grep -Fq "from testapp.chat_ui" "${PROJECT}/src/testapp/main.py"
}

@test "layer_streamlit_chat: __init__.py uses relative import" {
  apply_layer_streamlit_chat "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "from .api import" "${PROJECT}/src/testapp/chat_ui/__init__.py"
}

# ── Idempotency ───────────────────────────────────────────────────

@test "layer_streamlit_chat: idempotent" {
  apply_layer_streamlit_chat "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local snap1="${TEST_TEMP}/snap1"
  mkdir -p "$snap1"
  cp -a "$PROJECT" "$snap1/project"

  apply_layer_streamlit_chat "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  diff -rq "$snap1/project" "$PROJECT"
}

# ── Metadata ──────────────────────────────────────────────────────

@test "layer_streamlit_chat: phase is infra-inject" {
  local phase
  phase="$(grep -m1 '^_LAYER_PHASE=' "${REPO_ROOT}/lib/layers/python/streamlit-chat.sh" | cut -d'"' -f2)"
  assert_equal "$phase" "infra-inject"
}

@test "layer_streamlit_chat: requires streamlit" {
  local requires
  requires="$(grep -m1 '^_LAYER_REQUIRES=' "${REPO_ROOT}/lib/layers/python/streamlit-chat.sh" | cut -d'"' -f2)"
  assert_equal "$requires" "streamlit"
}

# ── Flat layout ───────────────────────────────────────────────────

_setup_flat_project_with_streamlit() {
  local flat_project="${TEST_TEMP}/flat_project_$$"
  mkdir -p "${flat_project}/tests"
  local tpl_dir="${REPO_ROOT}/templates/devcontainer/python"
  cp -r "${tpl_dir}/.devcontainer" "${flat_project}/.devcontainer"
  cp "${tpl_dir}/Dockerfile" "${flat_project}/"
  cp "${tpl_dir}/pyproject.toml" "${flat_project}/"
  cp "${tpl_dir}/main.py" "${flat_project}/"
  cp "${tpl_dir}/requirements.txt" "${flat_project}/"
  cp "${tpl_dir}/requirements-dev.txt" "${flat_project}/"
  [[ -f "${tpl_dir}/README.md" ]] && cp "${tpl_dir}/README.md" "${flat_project}/"
  [[ -d "${tpl_dir}/tests" ]] && cp "${tpl_dir}/tests/"* "${flat_project}/tests/" 2>/dev/null || true
  for f in "${tpl_dir}"/.[!.]*; do
    [[ -e "$f" ]] && [[ ! -d "$f" ]] && cp "$f" "${flat_project}/"
  done

  # Apply streamlit prerequisite
  apply_layer_streamlit "$flat_project" "testapp" "python" "${flat_project}/.devcontainer" >&2
  echo "$flat_project"
}

@test "layer_streamlit_chat: flat layout → chat_ui/ at project root" {
  local flat_project; flat_project="$(_setup_flat_project_with_streamlit)"
  apply_layer_streamlit_chat "$flat_project" "testapp" "python" "${flat_project}/.devcontainer"
  assert [ -d "${flat_project}/chat_ui" ]
  assert [ -f "${flat_project}/chat_ui/__init__.py" ]
  assert [ -f "${flat_project}/chat_ui/api.py" ]
}

@test "layer_streamlit_chat: flat layout → __init__.py uses relative import" {
  local flat_project; flat_project="$(_setup_flat_project_with_streamlit)"
  apply_layer_streamlit_chat "$flat_project" "testapp" "python" "${flat_project}/.devcontainer"
  grep -Fq "from .api import" "${flat_project}/chat_ui/__init__.py"
}

@test "layer_streamlit_chat: flat layout → main.py uses bare import" {
  local flat_project; flat_project="$(_setup_flat_project_with_streamlit)"
  apply_layer_streamlit_chat "$flat_project" "testapp" "python" "${flat_project}/.devcontainer"
  grep -Fq "from chat_ui.api import" "${flat_project}/main.py"
}

@test "layer_streamlit_chat: flat layout → test uses correct path" {
  local flat_project; flat_project="$(_setup_flat_project_with_streamlit)"
  apply_layer_streamlit_chat "$flat_project" "testapp" "python" "${flat_project}/.devcontainer"
  grep -Fq 'from_file("main.py")' "${flat_project}/tests/test_main.py"
}
