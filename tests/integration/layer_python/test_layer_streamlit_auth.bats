#!/usr/bin/env bats
# tests/integration/layer_python/test_layer_streamlit_auth.bats

setup() {
  load '../../helpers/layer_test_helper'
  _common_setup
  PROJECT="$(setup_project_scaffold "testapp")"
  source_layer "${REPO_ROOT}/lib/layers/python/src.sh"
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  source_layer "${REPO_ROOT}/lib/layers/python/streamlit.sh"
  apply_layer_streamlit "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  source_layer "${REPO_ROOT}/lib/layers/python/streamlit-auth.sh"
}

teardown() {
  _common_teardown
}

# ── Core artifacts ────────────────────────────────────────────────

@test "layer_streamlit_auth: creates users/ package" {
  apply_layer_streamlit_auth "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -d "${PROJECT}/src/testapp/users" ]
  assert [ -f "${PROJECT}/src/testapp/users/__init__.py" ]
  assert [ -f "${PROJECT}/src/testapp/users/__main__.py" ]
  assert [ -f "${PROJECT}/src/testapp/users/gate.py" ]
  assert [ -f "${PROJECT}/src/testapp/users/store.py" ]
  assert [ -f "${PROJECT}/src/testapp/users/cli.py" ]
}

@test "layer_streamlit_auth: creates users_data/ with example + README" {
  apply_layer_streamlit_auth "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -f "${PROJECT}/users_data/credentials.example.yaml" ]
  assert [ -f "${PROJECT}/users_data/README.md" ]
}

@test "layer_streamlit_auth: requirements.txt has streamlit-authenticator, bcrypt, PyYAML" {
  apply_layer_streamlit_auth "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "streamlit-authenticator" "${PROJECT}/requirements.txt"
  grep -Fq "bcrypt" "${PROJECT}/requirements.txt"
  grep -Fq "PyYAML" "${PROJECT}/requirements.txt"
}

@test "layer_streamlit_auth: .env.example has AUTH_* keys" {
  apply_layer_streamlit_auth "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "AUTH_COOKIE_KEY=" "${PROJECT}/.env.example"
  grep -Fq "AUTH_COOKIE_NAME=" "${PROJECT}/.env.example"
  grep -Fq "AUTH_CREDENTIALS_PATH=" "${PROJECT}/.env.example"
}

@test "layer_streamlit_auth: .env.example cookie key is the placeholder (forces user to regen)" {
  apply_layer_streamlit_auth "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "AUTH_COOKIE_KEY=change-me-run-gen-cookie-key" "${PROJECT}/.env.example"
}

@test "layer_streamlit_auth: .gitignore ignores users_data/credentials.yaml" {
  apply_layer_streamlit_auth "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "users_data/credentials.yaml" "${PROJECT}/.gitignore"
}

@test "layer_streamlit_auth: .dockerignore ignores users_data/credentials.yaml" {
  apply_layer_streamlit_auth "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "users_data/credentials.yaml" "${PROJECT}/.dockerignore"
}

@test "layer_streamlit_auth: README has Authentication section" {
  apply_layer_streamlit_auth "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "## Authentication" "${PROJECT}/README.md"
}

@test "layer_streamlit_auth: example yaml never contains a real bcrypt hash" {
  apply_layer_streamlit_auth "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  ! grep -Eq '\$2[aby]\$[0-9]{2}\$' "${PROJECT}/users_data/credentials.example.yaml"
}

@test "layer_streamlit_auth: unit test file created" {
  apply_layer_streamlit_auth "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -f "${PROJECT}/tests/unit/test_users.py" ]
}

@test "layer_streamlit_auth: unit test imports rewritten for src layout" {
  apply_layer_streamlit_auth "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "from testapp.users.store import" "${PROJECT}/tests/unit/test_users.py"
  ! grep -Fq "from users.store import" "${PROJECT}/tests/unit/test_users.py"
}

# ── Does not modify user's main.py / compose / devcontainer ──────

@test "layer_streamlit_auth: does NOT modify main.py" {
  local before
  before="$(sha256sum "${PROJECT}/src/testapp/main.py" | cut -d' ' -f1)"
  apply_layer_streamlit_auth "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local after
  after="$(sha256sum "${PROJECT}/src/testapp/main.py" | cut -d' ' -f1)"
  assert_equal "$before" "$after"
}

@test "layer_streamlit_auth: does NOT modify compose.yaml" {
  [[ -f "${PROJECT}/compose.yaml" ]] || skip "compose.yaml not present"
  local before
  before="$(sha256sum "${PROJECT}/compose.yaml" | cut -d' ' -f1)"
  apply_layer_streamlit_auth "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local after
  after="$(sha256sum "${PROJECT}/compose.yaml" | cut -d' ' -f1)"
  assert_equal "$before" "$after"
}

@test "layer_streamlit_auth: does NOT modify devcontainer.json" {
  local before
  before="$(sha256sum "${PROJECT}/.devcontainer/devcontainer.json" | cut -d' ' -f1)"
  apply_layer_streamlit_auth "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local after
  after="$(sha256sum "${PROJECT}/.devcontainer/devcontainer.json" | cut -d' ' -f1)"
  assert_equal "$before" "$after"
}

# ── Idempotency ───────────────────────────────────────────────────

@test "layer_streamlit_auth: idempotent (no diff on second apply)" {
  apply_layer_streamlit_auth "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local snap="${TEST_TEMP}/snap"
  mkdir -p "$snap"
  cp -a "$PROJECT" "$snap/project"

  apply_layer_streamlit_auth "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  diff -rq "$snap/project" "$PROJECT"
}

@test "layer_streamlit_auth: requirements line not duplicated on re-apply" {
  apply_layer_streamlit_auth "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_streamlit_auth "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  # Anchor to the dep line itself -- the base requirements.txt mentions
  # "streamlit-authenticator" in a comment, so an unanchored grep would
  # always count 2 even without duplication.
  local count
  count="$(grep -cE '^streamlit-authenticator>=' "${PROJECT}/requirements.txt")"
  assert_equal "$count" "1"
}

# ── Metadata ──────────────────────────────────────────────────────

@test "layer_streamlit_auth: phase is tooling" {
  local phase
  phase="$(grep -m1 '^_LAYER_PHASE=' "${REPO_ROOT}/lib/layers/python/streamlit-auth.sh" | cut -d'"' -f2)"
  assert_equal "$phase" "tooling"
}

@test "layer_streamlit_auth: requires streamlit" {
  local requires
  requires="$(grep -m1 '^_LAYER_REQUIRES=' "${REPO_ROOT}/lib/layers/python/streamlit-auth.sh" | cut -d'"' -f2)"
  assert_equal "$requires" "streamlit"
}

@test "layer_streamlit_auth: no conflicts declared" {
  local conflicts
  conflicts="$(grep -m1 '^_LAYER_CONFLICTS=' "${REPO_ROOT}/lib/layers/python/streamlit-auth.sh" | cut -d'"' -f2)"
  assert_equal "$conflicts" ""
}

# ── Python syntax ─────────────────────────────────────────────────

@test "layer_streamlit_auth: all generated .py files compile" {
  apply_layer_streamlit_auth "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  command -v python3 >/dev/null || skip "python3 not available"
  for f in "${PROJECT}/src/testapp/users/"*.py "${PROJECT}/tests/unit/test_users.py"; do
    python3 -m py_compile "$f"
  done
}

# ── Typing: templates must satisfy mypy --strict (no untyped defs, no bare dict) ──

@test "layer_streamlit_auth: store.py uses @contextmanager on _locked_write (typed generator)" {
  apply_layer_streamlit_auth "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Eq '@contextlib\.contextmanager' "${PROJECT}/src/testapp/users/store.py"
  grep -Eq 'def _locked_write\(self, path: Path\) -> Iterator\[TextIO\]' "${PROJECT}/src/testapp/users/store.py"
}

@test "layer_streamlit_auth: store.py has no leftover '# type: ignore[literal-required]'" {
  apply_layer_streamlit_auth "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  ! grep -Fq 'type: ignore[literal-required]' "${PROJECT}/src/testapp/users/store.py"
}

@test "layer_streamlit_auth: to_authenticator_credentials has typed return" {
  apply_layer_streamlit_auth "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Eq 'def to_authenticator_credentials\(' "${PROJECT}/src/testapp/users/store.py"
  grep -Eq -e '-> dict\[str, dict\[str, dict\[str, str\]\]\]' "${PROJECT}/src/testapp/users/store.py"
}

@test "layer_streamlit_auth: gate.py _read_config returns parametrized dict" {
  apply_layer_streamlit_auth "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Eq 'def _read_config\(\) -> dict\[str, str \| int\]' "${PROJECT}/src/testapp/users/gate.py"
}

@test "layer_streamlit_auth: test_users.py imports User TypedDict for upsert" {
  apply_layer_streamlit_auth "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Eq 'from\s+testapp\.users\.store\s+import\s*\(' "${PROJECT}/tests/unit/test_users.py"
  grep -Fq 'User,' "${PROJECT}/tests/unit/test_users.py"
  grep -Fq 'user = User(' "${PROJECT}/tests/unit/test_users.py"
}

# ── Lint: templates must satisfy ruff (SIM105, S110) ──────────────

@test "layer_streamlit_auth: gate.py uses contextlib.suppress (no try/except/pass)" {
  apply_layer_streamlit_auth "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq 'import contextlib' "${PROJECT}/src/testapp/users/gate.py"
  grep -Fq 'with contextlib.suppress(Exception):' "${PROJECT}/src/testapp/users/gate.py"
  # No bare try/except Exception followed by pass (ruff S110 + SIM105)
  ! grep -Pzoq '(?s)except Exception:[^\n]*\n\s+pass' "${PROJECT}/src/testapp/users/gate.py"
}

@test "layer_streamlit_auth: store.py uses contextlib.suppress for chmod (no try/except/pass)" {
  apply_layer_streamlit_auth "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq 'with contextlib.suppress(OSError):' "${PROJECT}/src/testapp/users/store.py"
  # Specifically: chmod must be inside a suppress block, not try/except
  ! grep -Pzoq '(?s)try:\s*\n\s+os\.chmod' "${PROJECT}/src/testapp/users/store.py"
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

  apply_layer_streamlit "$flat_project" "testapp" "python" "${flat_project}/.devcontainer" >&2
  echo "$flat_project"
}

@test "layer_streamlit_auth: flat layout → users/ at project root" {
  local flat_project; flat_project="$(_setup_flat_project_with_streamlit)"
  apply_layer_streamlit_auth "$flat_project" "testapp" "python" "${flat_project}/.devcontainer"
  assert [ -d "${flat_project}/users" ]
  assert [ -f "${flat_project}/users/__init__.py" ]
  assert [ -f "${flat_project}/users/store.py" ]
}

@test "layer_streamlit_auth: flat layout → unit test uses bare import" {
  local flat_project; flat_project="$(_setup_flat_project_with_streamlit)"
  apply_layer_streamlit_auth "$flat_project" "testapp" "python" "${flat_project}/.devcontainer"
  grep -Fq "from users.store import" "${flat_project}/tests/unit/test_users.py"
  ! grep -Fq "from testapp.users" "${flat_project}/tests/unit/test_users.py"
}

@test "layer_streamlit_auth: flat layout → users_data/ at project root" {
  local flat_project; flat_project="$(_setup_flat_project_with_streamlit)"
  apply_layer_streamlit_auth "$flat_project" "testapp" "python" "${flat_project}/.devcontainer"
  assert [ -f "${flat_project}/users_data/credentials.example.yaml" ]
  assert [ -f "${flat_project}/users_data/README.md" ]
}

# ── Co-existence with streamlit-chat ─────────────────────────────

@test "layer_streamlit_auth: coexists with streamlit-chat (both packages present)" {
  source_layer "${REPO_ROOT}/lib/layers/python/streamlit-chat.sh"
  apply_layer_streamlit_chat "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_streamlit_auth "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -d "${PROJECT}/src/testapp/chat_ui" ]
  assert [ -d "${PROJECT}/src/testapp/users" ]
  # streamlit-auth must not touch the main.py that streamlit-chat wrote
  grep -Fq "stream_message" "${PROJECT}/src/testapp/main.py"
  grep -Fq "st.chat_input" "${PROJECT}/src/testapp/main.py"
}
