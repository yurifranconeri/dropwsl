#!/usr/bin/env bats
# tests/integration/test_new_project.bats — Tests for new_project()
# Validates: standalone creation, name validation, merge of defaults, layers applied

setup() {
  load '../helpers/layer_test_helper'
  _common_setup
  activate_mocks
  export PROJECTS_DIR="${TEST_TEMP}/projects"
  mkdir -p "$PROJECTS_DIR"
  export NO_DEFAULTS=true
  export DEFAULT_LAYERS=()
  # Stub code and git to avoid side-effects
  code() { :; }
  export -f code
  git() { command git "$@"; }
  export -f git
}

teardown() {
  _common_teardown
}

@test "new_project: creates standalone project with complete structure" {
  new_project "meu-app" "python" "" "" >&2
  assert [ -d "${PROJECTS_DIR}/meu-app" ]
  assert [ -f "${PROJECTS_DIR}/meu-app/.devcontainer/Dockerfile" ]
  assert [ -f "${PROJECTS_DIR}/meu-app/.devcontainer/devcontainer.json" ]
  assert [ -f "${PROJECTS_DIR}/meu-app/pyproject.toml" ]
  assert [ -f "${PROJECTS_DIR}/meu-app/main.py" ]
  assert [ -f "${PROJECTS_DIR}/meu-app/requirements.txt" ]
}

@test "new_project: git init in standalone" {
  new_project "git-test" "python" "" "" >&2
  assert [ -d "${PROJECTS_DIR}/git-test/.git" ]
}

@test "new_project: project name in pyproject.toml" {
  new_project "my-svc" "python" "" "" >&2
  grep -Fq 'name = "my-svc"' "${PROJECTS_DIR}/my-svc/pyproject.toml"
}

@test "new_project: applies passed layers" {
  new_project "layered" "python" "src,fastapi" "" >&2
  assert [ -d "${PROJECTS_DIR}/layered/src/layered" ]
  grep -Fq "from fastapi" "${PROJECTS_DIR}/layered/src/layered/main.py"
}

@test "new_project: numeric name with src and fastapi uses valid package import path" {
  new_project "121" "python" "src,fastapi,compose" "" >&2
  assert [ -d "${PROJECTS_DIR}/121/src/_121" ]
  grep -Fq 'uvicorn _121.main:app' "${PROJECTS_DIR}/121/README.md"
  grep -Fq 'CMD ["uvicorn", "_121.main:app", "--host", "0.0.0.0", "--port", "8000"]' "${PROJECTS_DIR}/121/Dockerfile"
}

@test "new_project: locust README stays generic without compose" {
  new_project "loadtest" "python" "locust" "" >&2
  ! grep -Fq 'docker compose up locust' "${PROJECTS_DIR}/loadtest/README.md"
  grep -Fq 'locust --headless -u 50 -r 10 -t 30s' "${PROJECTS_DIR}/loadtest/README.md"
}

@test "new_project: workspace mode merges locust env from service into workspace root" {
  new_project "myws" "python" "locust" "loadtest" >&2
  grep -Fq 'LOCUST_HOST=http://target-service:8000' "${PROJECTS_DIR}/myws/.env.example"
}

@test "new_project: empty name → die" {
  run new_project "" "python" "" ""
  assert_failure
  assert_output --partial "Usage:"
}

@test "new_project: name with spaces → die" {
  run new_project "my app" "python" "" ""
  assert_failure
  assert_output --partial "Invalid"
}

@test "new_project: name starting with - → die" {
  run new_project "-badname" "python" "" ""
  assert_failure
  assert_output --partial "Invalid"
}

@test "new_project: name starting with . → die" {
  run new_project ".hidden" "python" "" ""
  assert_failure
  assert_output --partial "Invalid"
}

@test "new_project: empty language → die" {
  run new_project "meu-app" "" "" ""
  assert_failure
}

@test "new_project: merge default layers" {
  export NO_DEFAULTS=false
  export DEFAULT_LAYERS=("src")
  new_project "with-defaults" "python" "fastapi" "" >&2
  # src comes from defaults, fastapi from user
  assert [ -d "${PROJECTS_DIR}/with-defaults/src/with_defaults" ]
  grep -Fq "from fastapi" "${PROJECTS_DIR}/with-defaults/src/with_defaults/main.py"
}

@test "new_project: --no-defaults ignora DEFAULT_LAYERS" {
  export NO_DEFAULTS=true
  export DEFAULT_LAYERS=("src")
  new_project "no-defaults" "python" "" "" >&2
  # Without src layer, main.py stays at root
  assert [ -f "${PROJECTS_DIR}/no-defaults/main.py" ]
  assert [ ! -d "${PROJECTS_DIR}/no-defaults/src" ]
}

@test "new_project: idempotent — re-execution does not fail" {
  export ASSUME_YES=true
  new_project "idem-test" "python" "" "" >&2 < /dev/null
  # Verify it was created
  assert [ -f "${PROJECTS_DIR}/idem-test/main.py" ]
  # Second run: even with existing directory, ASSUME_YES skips prompt
  new_project "idem-test" "python" "" "" >&2 < /dev/null
  assert [ -f "${PROJECTS_DIR}/idem-test/main.py" ]
}
