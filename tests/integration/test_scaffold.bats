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
