#!/usr/bin/env bats
# tests/unit/test_detect_python_layout.bats — Tests for _detect_python_layout()

setup() {
  load '../helpers/test_helper'
  _common_setup
  TEST_PROJECT="$(mktemp -d)"
}

teardown() {
  rm -rf "$TEST_PROJECT"
  _common_teardown
}

@test "_detect_python_layout: flat layout without src" {
  mkdir -p "$TEST_PROJECT"
  echo 'print("hi")' > "$TEST_PROJECT/main.py"

  _detect_python_layout "$TEST_PROJECT" "my_project"

  assert_equal "$_HAS_SRC" "false"
  assert_equal "$_PKG_BASE" "$TEST_PROJECT"
  assert_equal "$_HAS_API_FRAMEWORK" "false"
  assert_equal "$_HAS_COMPOSE" "false"
  assert_equal "$_HAS_LOCAL_INFRA" "false"
}

@test "_detect_python_layout: src layout detected" {
  mkdir -p "$TEST_PROJECT/src/my_project"
  echo 'print("hi")' > "$TEST_PROJECT/src/my_project/main.py"

  _detect_python_layout "$TEST_PROJECT" "my_project"

  assert_equal "$_HAS_SRC" "true"
  assert_equal "$_PKG_BASE" "$TEST_PROJECT/src/my_project"
}

@test "_detect_python_layout: detects FastAPI" {
  mkdir -p "$TEST_PROJECT"
  echo 'app = FastAPI(title="test")' > "$TEST_PROJECT/main.py"

  _detect_python_layout "$TEST_PROJECT" "my_project"

  assert_equal "$_HAS_API_FRAMEWORK" "true"
}

@test "_detect_python_layout: detects FastAPI in src layout" {
  mkdir -p "$TEST_PROJECT/src/my_svc"
  echo 'app = FastAPI(title="test")' > "$TEST_PROJECT/src/my_svc/main.py"

  _detect_python_layout "$TEST_PROJECT" "my_svc"

  assert_equal "$_HAS_SRC" "true"
  assert_equal "$_HAS_API_FRAMEWORK" "true"
}

@test "_detect_python_layout: detects compose.yaml" {
  mkdir -p "$TEST_PROJECT"
  echo 'services: {}' > "$TEST_PROJECT/compose.yaml"

  _detect_python_layout "$TEST_PROJECT" "my_project"

  assert_equal "$_HAS_COMPOSE" "true"
  assert_equal "$_HAS_LOCAL_INFRA" "false"
}

@test "_detect_python_layout: no compose means false" {
  mkdir -p "$TEST_PROJECT"

  _detect_python_layout "$TEST_PROJECT" "my_project"

  assert_equal "$_HAS_COMPOSE" "false"
  assert_equal "$_HAS_LOCAL_INFRA" "false"
}

@test "_detect_python_layout: local infra marker enables explicit local provider" {
  mkdir -p "$TEST_PROJECT"
  echo 'services: {}' > "$TEST_PROJECT/compose.yaml"
  cat > "$TEST_PROJECT/.env.example" <<'EOF'
# -- dropwsl:local-infra --
EOF

  _detect_python_layout "$TEST_PROJECT" "my_project"

  assert_equal "$_HAS_COMPOSE" "true"
  assert_equal "$_HAS_LOCAL_INFRA" "true"
}

@test "_detect_python_layout: no main.py means no API framework" {
  mkdir -p "$TEST_PROJECT/src/my_project"

  _detect_python_layout "$TEST_PROJECT" "my_project"

  assert_equal "$_HAS_SRC" "true"
  assert_equal "$_HAS_API_FRAMEWORK" "false"
}
