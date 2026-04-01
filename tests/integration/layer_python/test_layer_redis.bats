#!/usr/bin/env bats
# tests/integration/layer_python/test_layer_redis.bats

setup() {
  load '../../helpers/layer_test_helper'
  _common_setup
  PROJECT="$(setup_project_scaffold "testapp")"
  source_layer "${REPO_ROOT}/lib/layers/python/src.sh"
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  source_layer "${REPO_ROOT}/lib/layers/shared/compose.sh"
  source_layer "${REPO_ROOT}/lib/layers/python/redis.sh"
}

teardown() {
  _common_teardown
}

@test "layer_redis: creates src/{pkg}/cache/" {
  apply_layer_redis "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  assert [ -d "${PROJECT}/src/testapp/cache" ]
  assert [ -f "${PROJECT}/src/testapp/cache/__init__.py" ]
  assert [ -f "${PROJECT}/src/testapp/cache/client.py" ]
  assert [ -f "${PROJECT}/tests/fixtures/cache.py" ]
  assert [ -f "${PROJECT}/tests/unit/test_cache.py" ]
}

@test "layer_redis: .env.example contains REDIS_URL" {
  apply_layer_redis "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "REDIS_URL" "${PROJECT}/.env.example"
}

@test "layer_redis: compose.yaml contains service redis" {
  apply_layer_compose "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_redis "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "redis" "${PROJECT}/compose.yaml"
}

@test "layer_redis: with FastAPI → async client" {
  source_layer "${REPO_ROOT}/lib/layers/python/fastapi.sh"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_redis "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -q "async\|redis.asyncio\|aioredis" "${PROJECT}/src/testapp/cache/client.py"
}

@test "layer_redis: idempotent" {
  apply_layer_redis "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local snap1="${TEST_TEMP}/snap1"
  find "${PROJECT}/src/testapp/cache" -type f | sort | xargs md5sum > "$snap1" 2>/dev/null || true
  apply_layer_redis "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local snap2="${TEST_TEMP}/snap2"
  find "${PROJECT}/src/testapp/cache" -type f | sort | xargs md5sum > "$snap2" 2>/dev/null || true
  diff "$snap1" "$snap2"
}

@test "layer_redis: no CRLF" {
  apply_layer_redis "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  ! grep -rP '\r' "${PROJECT}/src/testapp/cache/" 2>/dev/null
}

# ---- Adaptive behavior: with compose vs without compose ----

@test "layer_redis: with compose → client.py has default hostname" {
  apply_layer_compose "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_redis "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq 'redis://redis:6379/0' "${PROJECT}/src/testapp/cache/client.py"
  ! grep -Fq 'RuntimeError' "${PROJECT}/src/testapp/cache/client.py"
}

@test "layer_redis: without compose → client.py has RuntimeError" {
  apply_layer_redis "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq 'RuntimeError' "${PROJECT}/src/testapp/cache/client.py"
  grep -Fq 'REDIS_URL' "${PROJECT}/src/testapp/cache/client.py"
  ! grep -Fq 'redis://redis:6379' "${PROJECT}/src/testapp/cache/client.py"
}

@test "layer_redis: without compose → .env.example uses placeholder" {
  apply_layer_redis "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq 'redis://host:6379/0' "${PROJECT}/.env.example"
}

@test "layer_redis: with compose → .env.example has hostname" {
  apply_layer_compose "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_redis "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq 'redis://redis:6379/0' "${PROJECT}/.env.example"
}

@test "layer_redis: without compose + FastAPI → test_cache.py has REDIS_URL setdefault" {
  source_layer "${REPO_ROOT}/lib/layers/python/fastapi.sh"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_redis "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq 'os.environ.setdefault("REDIS_URL"' "${PROJECT}/tests/unit/test_cache.py"
}

@test "layer_redis: with compose + FastAPI → test_cache.py without setdefault" {
  source_layer "${REPO_ROOT}/lib/layers/python/fastapi.sh"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_compose "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_redis "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  ! grep -Fq 'os.environ.setdefault' "${PROJECT}/tests/unit/test_cache.py"
}
