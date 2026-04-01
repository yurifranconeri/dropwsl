#!/usr/bin/env bats
# tests/integration/layer_python/test_layer_postgres.bats

setup() {
  load '../../helpers/layer_test_helper'
  _common_setup
  PROJECT="$(setup_project_scaffold "testapp")"
  # Postgres requer src layout
  source_layer "${REPO_ROOT}/lib/layers/python/src.sh"
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  source_layer "${REPO_ROOT}/lib/layers/shared/compose.sh"
  source_layer "${REPO_ROOT}/lib/layers/python/postgres.sh"
}

teardown() {
  _common_teardown
}

@test "layer_postgres: creates src/{pkg}/db/" {
  apply_layer_postgres "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -d "${PROJECT}/src/testapp/db" ]
  assert [ -f "${PROJECT}/src/testapp/db/__init__.py" ]
  assert [ -f "${PROJECT}/src/testapp/db/models.py" ]
  assert [ -f "${PROJECT}/src/testapp/db/engine.py" ]
  assert [ -f "${PROJECT}/src/testapp/db/service.py" ]
  assert [ -f "${PROJECT}/tests/fixtures/db.py" ]
  assert [ -f "${PROJECT}/tests/unit/test_db.py" ]
}

@test "layer_postgres: .env.example contains DATABASE_URL" {
  apply_layer_postgres "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "DATABASE_URL" "${PROJECT}/.env.example"
}

@test "layer_postgres: compose.yaml contains service postgres" {
  apply_layer_compose "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_postgres "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "postgres" "${PROJECT}/compose.yaml"
}

@test "layer_postgres: requirements.txt contains sqlalchemy" {
  apply_layer_postgres "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -qi "sqlalchemy" "${PROJECT}/requirements.txt"
}

@test "layer_postgres: idempotent" {
  apply_layer_postgres "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local snap1="${TEST_TEMP}/snap1"
  find "${PROJECT}/src/testapp/db" -type f | sort | xargs md5sum > "$snap1" 2>/dev/null || true
  apply_layer_postgres "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local snap2="${TEST_TEMP}/snap2"
  find "${PROJECT}/src/testapp/db" -type f | sort | xargs md5sum > "$snap2" 2>/dev/null || true
  diff "$snap1" "$snap2"
}

@test "layer_postgres: with FastAPI → engine with get_session" {
  source_layer "${REPO_ROOT}/lib/layers/python/src.sh"
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  source_layer "${REPO_ROOT}/lib/layers/python/fastapi.sh"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_postgres "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -q "create_engine\|get_session" "${PROJECT}/src/testapp/db/engine.py"
}

@test "layer_postgres: no CRLF in generated files" {
  apply_layer_postgres "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  ! grep -rP '\r' "${PROJECT}/src/testapp/db/" 2>/dev/null
}

# ---- Adaptive behavior: with compose vs without compose ----

@test "layer_postgres: with compose → engine.py has default hostname" {
  apply_layer_compose "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_postgres "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq '@postgres:5432' "${PROJECT}/src/testapp/db/engine.py"
  ! grep -Fq 'RuntimeError' "${PROJECT}/src/testapp/db/engine.py"
}

@test "layer_postgres: without compose → engine.py has RuntimeError" {
  apply_layer_postgres "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq 'RuntimeError' "${PROJECT}/src/testapp/db/engine.py"
  grep -Fq 'DATABASE_URL' "${PROJECT}/src/testapp/db/engine.py"
  ! grep -Fq '@postgres:5432' "${PROJECT}/src/testapp/db/engine.py"
}

@test "layer_postgres: without compose → .env.example uses placeholder" {
  apply_layer_postgres "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq 'user:pass@host:5432' "${PROJECT}/.env.example"
  ! grep -Fq 'POSTGRES_USER' "${PROJECT}/.env.example"
}

@test "layer_postgres: with compose → .env.example has hostname and POSTGRES_USER" {
  apply_layer_compose "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_postgres "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq '@postgres:5432' "${PROJECT}/.env.example"
  grep -Fq 'POSTGRES_USER' "${PROJECT}/.env.example"
}

@test "layer_postgres: without compose + FastAPI → fixtures/db.py has DATABASE_URL setdefault" {
  source_layer "${REPO_ROOT}/lib/layers/python/fastapi.sh"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_postgres "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq 'os.environ.setdefault("DATABASE_URL"' "${PROJECT}/tests/fixtures/db.py"
  grep -Fq 'tests.fixtures.db' "${PROJECT}/tests/conftest.py"
}

@test "layer_postgres: with compose + FastAPI → fixtures/db.py without setdefault" {
  source_layer "${REPO_ROOT}/lib/layers/python/fastapi.sh"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_compose "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_postgres "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  ! grep -Fq 'os.environ.setdefault' "${PROJECT}/tests/fixtures/db.py"
}

@test "layer_postgres: without compose + FastAPI → lifespan warning indicates .env" {
  source_layer "${REPO_ROOT}/lib/layers/python/fastapi.sh"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_postgres "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq 'Configure DATABASE_URL in .env.' "${PROJECT}/src/testapp/main.py"
  ! grep -Fq "docker compose up" "${PROJECT}/src/testapp/main.py"
}
