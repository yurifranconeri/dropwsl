#!/usr/bin/env bats
# tests/integration/test_scaffold.bats — Tests for scaffold_devcontainer()

setup() {
  load '../helpers/layer_test_helper'
  _common_setup
}

teardown() {
  _common_teardown
}

@test "scaffold: Python generates all files" {
  cd "$TEST_TEMP"
  scaffold_devcontainer "python" false
  assert [ -f ".devcontainer/Dockerfile" ]
  assert [ -f "pyproject.toml" ]
  assert [ -f "main.py" ]
  assert [ -f "requirements.txt" ]
  assert [ -f "requirements-dev.txt" ]
}

@test "scaffold: pyproject.toml ignores T20 for __main__.py runners" {
  cd "$TEST_TEMP"
  scaffold_devcontainer "python" false
  grep -Fq '"**/__main__.py"' "pyproject.toml"
}

@test "scaffold: pyproject.toml ignores T20 for cli.py CLI implementations" {
  # cli.py is the dropwsl convention for capability-layer CLI command
  # implementations (pydantic-settings, streamlit-auth, ...). It uses print()
  # as the intended user output and must be exempt from T20 like __main__.py.
  cd "$TEST_TEMP"
  scaffold_devcontainer "python" false
  grep -Fq '"**/cli.py"' "pyproject.toml"
}

@test "scaffold: no-clobber — existing file is not overwritten" {
  cd "$TEST_TEMP"
  echo "meu conteudo original" > main.py
  scaffold_devcontainer "python" false
  local content
  content="$(cat main.py)"
  assert [ "$content" = "meu conteudo original" ]
}

@test "scaffold: Dockerfile contains deps-hash marker" {
  cd "$TEST_TEMP"
  scaffold_devcontainer "python" false
  grep -Fq '.deps-hash' ".devcontainer/Dockerfile"
}

@test "scaffold: post-create.sh uses deps-hash for skip" {
  cd "$TEST_TEMP"
  scaffold_devcontainer "python" false
  grep -Fq '_deps_hash' ".devcontainer/post-create.sh"
}

@test "scaffold: devcontainer.json contains required base extensions" {
  cd "$TEST_TEMP"
  scaffold_devcontainer "python" false
  local dc=".devcontainer/devcontainer.json"
  assert [ -f "$dc" ]
  # Fundamental extensions for the Python workflow
  grep -Fq 'ms-python.python' "$dc"
  grep -Fq 'ms-python.vscode-pylance' "$dc"
  grep -Fq 'charliermarsh.ruff' "$dc"
  grep -Fq 'GitHub.copilot-chat' "$dc"
  grep -Fq 'EditorConfig.EditorConfig' "$dc"
  grep -Fq 'eamodio.gitlens' "$dc"
  grep -Fq 'ms-azuretools.vscode-docker' "$dc"
}

@test "scaffold: devcontainer.json does not contain deprecated extensions" {
  cd "$TEST_TEMP"
  scaffold_devcontainer "python" false
  local dc=".devcontainer/devcontainer.json"
  # GitHub.copilot (without -chat) is deprecated — only copilot-chat should exist
  run grep -F '"GitHub.copilot"' "$dc"
  assert_failure
  # debugpy is an automatic dependency of ms-python.python
  run grep -F 'ms-python.debugpy' "$dc"
  assert_failure
}

@test "scaffold: invalid language → die" {
  cd "$TEST_TEMP"
  run scaffold_devcontainer "cobol_fantasy_lang" false
  assert_failure
}

# ---- Dev Dockerfile contract: venv must be writable by non-root user ----
# Regression guard for the bug where pip ran as root, created root-owned files
# in /opt/venv/lib/.../site-packages, and subsequent `pip install` as $USERNAME
# fell back to ~/.local (PEP 370), invisible to the venv interpreter.

@test "scaffold: Dockerfile switches to non-root USER before venv creation" {
  cd "$TEST_TEMP"
  scaffold_devcontainer "python" false
  local df=".devcontainer/Dockerfile"
  # Extract line numbers
  local user_line venv_line
  user_line="$(grep -n '^USER \$USERNAME' "$df" | head -1 | cut -d: -f1)"
  venv_line="$(grep -n 'python -m venv \$VIRTUAL_ENV' "$df" | head -1 | cut -d: -f1)"
  assert [ -n "$user_line" ]
  assert [ -n "$venv_line" ]
  # USER directive must come BEFORE the venv create
  [ "$user_line" -lt "$venv_line" ]
}

@test "scaffold: Dockerfile does not chown VIRTUAL_ENV (venv must be created by user)" {
  cd "$TEST_TEMP"
  scaffold_devcontainer "python" false
  # No chown on the venv anywhere — would mask permission bugs
  run grep -E 'chown.*VIRTUAL_ENV|chown.*\$\{?VIRTUAL_ENV' ".devcontainer/Dockerfile"
  assert_failure
}

@test "scaffold: Dockerfile pre-creates /opt with $USERNAME ownership" {
  cd "$TEST_TEMP"
  scaffold_devcontainer "python" false
  # /opt must be owned by $USERNAME so `python -m venv /opt/venv` succeeds unprivileged
  grep -Eq 'install -d -o \$USERNAME .* /opt' ".devcontainer/Dockerfile"
}

@test "scaffold: Dockerfile pip install uses user-owned cache mount" {
  cd "$TEST_TEMP"
  scaffold_devcontainer "python" false
  # Cache must point at $USERNAME's home with matching uid/gid,
  # otherwise BuildKit creates a root-owned cache the user cannot read.
  grep -Fq 'target=/home/vscode/.cache/pip' ".devcontainer/Dockerfile"
  grep -Fq 'uid=1000,gid=1000' ".devcontainer/Dockerfile"
}
