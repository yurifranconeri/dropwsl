#!/usr/bin/env bats
# tests/integration/combinations/test_combo_standalone_infra.bats
# Validates: standalone mode with compose + postgres/redis → network injection in devcontainer.json.
# Validates: standalone without compose → no network injection.

setup() {
  load '../../helpers/layer_test_helper'
  _common_setup
  PROJECT="$(setup_project_scaffold "testapp")"
  source_layer "${REPO_ROOT}/lib/layers/python/src.sh"
  source_layer "${REPO_ROOT}/lib/layers/python/fastapi.sh"
  source_layer "${REPO_ROOT}/lib/layers/shared/compose.sh"
  source_layer "${REPO_ROOT}/lib/layers/python/postgres.sh"
  source_layer "${REPO_ROOT}/lib/layers/python/redis.sh"
  source_layer "${REPO_ROOT}/lib/layers/python/uv.sh"
}

teardown() {
  _common_teardown
}

# ---- Standalone + compose + postgres ----

@test "standalone_infra: compose injects initializeCommand in devcontainer.json" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_compose "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_postgres "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"

  grep -Fq '"initializeCommand"' "${PROJECT}/.devcontainer/devcontainer.json"
  # initializeCommand uses docker compose to create network with proper labels
  grep -Fq 'docker compose down' "${PROJECT}/.devcontainer/devcontainer.json"
  grep -Fq 'docker compose up --no-start' "${PROJECT}/.devcontainer/devcontainer.json"
}

@test "standalone_infra: compose injects runArgs with network name" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_compose "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_postgres "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"

  grep -Fq '"--network=testapp-net"' "${PROJECT}/.devcontainer/devcontainer.json"
}

@test "standalone_infra: compose network name matches compose.yaml" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_compose "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_postgres "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"

  # compose.yaml defines named network (compose-managed)
  grep -Fq "testapp-net" "${PROJECT}/compose.yaml"
  # Default network is NOT external (works in standalone WSL too)
  ! grep -Fq "external: true" "${PROJECT}/compose.yaml"
  # devcontainer.json joins same network
  grep -Fq "testapp-net" "${PROJECT}/.devcontainer/devcontainer.json"
}

@test "standalone_infra: postgres service hostname resolvable via same network" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_compose "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_postgres "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"

  # DATABASE_URL uses hostname 'postgres' which resolves via compose network
  grep -Fq '@postgres:5432' "${PROJECT}/src/testapp/db/engine.py"
  # compose.yaml has the postgres service
  grep -Fq 'postgres:' "${PROJECT}/compose.yaml"
  # dev container joins the network
  grep -Fq '"runArgs"' "${PROJECT}/.devcontainer/devcontainer.json"
}

# ---- Standalone + compose + redis ----

@test "standalone_infra: redis service + compose network" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_compose "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_redis "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"

  # compose has redis
  grep -Fq 'redis:' "${PROJECT}/compose.yaml"
  # dev container on same network
  grep -Fq '"--network=testapp-net"' "${PROJECT}/.devcontainer/devcontainer.json"
}

# ---- Standalone + compose + postgres + redis ----

@test "standalone_infra: full stack has both services and network" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_compose "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_postgres "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_redis "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"

  grep -Fq 'postgres:' "${PROJECT}/compose.yaml"
  grep -Fq 'redis:' "${PROJECT}/compose.yaml"
  grep -Fq '"initializeCommand"' "${PROJECT}/.devcontainer/devcontainer.json"
  grep -Fq '"--network=testapp-net"' "${PROJECT}/.devcontainer/devcontainer.json"
}

@test "standalone_infra: full stack + uv applied" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_compose "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_postgres "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_redis "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_uv "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"

  # uv replaces pip in dev Dockerfile
  grep -Fq 'ghcr.io/astral-sh/uv' "${PROJECT}/.devcontainer/Dockerfile"
  # Network still present
  grep -Fq '"--network=testapp-net"' "${PROJECT}/.devcontainer/devcontainer.json"
}

# ---- Standalone + postgres WITHOUT compose → RuntimeError no engine.py ----

@test "standalone_infra: postgres without compose has RuntimeError in engine.py" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  # Postgres without compose layer — user brings own DB
  apply_layer_postgres "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"

  # engine.py has RuntimeError (no default hostname)
  grep -Fq 'RuntimeError' "${PROJECT}/src/testapp/db/engine.py"
  ! grep -Fq '@postgres:5432' "${PROJECT}/src/testapp/db/engine.py"
  # .env.example has placeholder DATABASE_URL (bring your own DB)
  grep -Fq "DATABASE_URL" "${PROJECT}/.env.example"
  grep -Fq 'user:pass@host:5432' "${PROJECT}/.env.example"
  # No network injection (compose layer not applied)
  ! grep -Fq '"initializeCommand"' "${PROJECT}/.devcontainer/devcontainer.json"
  ! grep -Fq '"runArgs"' "${PROJECT}/.devcontainer/devcontainer.json"
}

@test "standalone_infra: redis without compose has RuntimeError in client.py" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_redis "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"

  grep -Fq 'RuntimeError' "${PROJECT}/src/testapp/cache/client.py"
  ! grep -Fq 'redis://redis:6379' "${PROJECT}/src/testapp/cache/client.py"
  grep -Fq 'redis://host:6379/0' "${PROJECT}/.env.example"
}

@test "standalone_infra: postgres+redis without compose → both have RuntimeError" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_postgres "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_redis "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"

  grep -Fq 'RuntimeError' "${PROJECT}/src/testapp/db/engine.py"
  grep -Fq 'RuntimeError' "${PROJECT}/src/testapp/cache/client.py"
  # fixtures have setdefaults
  grep -Fq 'os.environ.setdefault("DATABASE_URL"' "${PROJECT}/tests/fixtures/db.py"
  grep -Fq 'os.environ.setdefault("REDIS_URL"' "${PROJECT}/tests/conftest.py"
}

# ---- Network injection is idempotent ----

@test "standalone_infra: network injection idempotent across full stack" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_compose "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_postgres "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_redis "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_uv "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"

  local snap1="${TEST_TEMP}/dc_snap1"
  cat "${PROJECT}/.devcontainer/devcontainer.json" > "$snap1"

  # Re-apply all layers
  apply_layer_compose "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_postgres "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_redis "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_uv "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"

  diff "$snap1" "${PROJECT}/.devcontainer/devcontainer.json"
}

# ---- devcontainer.json is valid JSON after injection ----

@test "standalone_infra: devcontainer.json valid after all injections" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_compose "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_postgres "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_redis "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_uv "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"

  # JSONC: devcontainer.json may have // comments from template
  assert_valid_jsonc "${PROJECT}/.devcontainer/devcontainer.json"
}
