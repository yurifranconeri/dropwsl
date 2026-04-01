#!/usr/bin/env bats
# tests/integration/combinations/test_combo_full_stack.bats

setup() {
  load '../../helpers/layer_test_helper'
  _common_setup
  PROJECT="$(setup_project_scaffold "testapp")"
  # Source all layers in phase order
  source_layer "${REPO_ROOT}/lib/layers/python/src.sh"
  source_layer "${REPO_ROOT}/lib/layers/python/fastapi.sh"
  source_layer "${REPO_ROOT}/lib/layers/python/mypy.sh"
  source_layer "${REPO_ROOT}/lib/layers/shared/compose.sh"
  source_layer "${REPO_ROOT}/lib/layers/python/azure-identity.sh"
  source_layer "${REPO_ROOT}/lib/layers/python/postgres.sh"
  source_layer "${REPO_ROOT}/lib/layers/python/redis.sh"
  source_layer "${REPO_ROOT}/lib/layers/python/testcontainers.sh"
  source_layer "${REPO_ROOT}/lib/layers/python/uv.sh"
  source_layer "${REPO_ROOT}/lib/layers/shared/gitleaks.sh"
  source_layer "${REPO_ROOT}/lib/layers/python/locust.sh"
}

teardown() {
  _common_teardown
}

@test "combo full_stack: all artifacts generated" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_mypy "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_compose "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_postgres "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_redis "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_testcontainers "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_uv "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_gitleaks "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_locust "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"

  # src layout
  assert [ -d "${PROJECT}/src/testapp" ]
  # FastAPI
  grep -Fq "from fastapi" "${PROJECT}/src/testapp/main.py"
  # mypy
  grep -Fq "[tool.mypy]" "${PROJECT}/pyproject.toml"
  # compose
  assert [ -f "${PROJECT}/compose.yaml" ]
  # azure-identity
  assert [ -d "${PROJECT}/src/testapp/auth" ]
  grep -Fq 'health_status["azure_identity"]' "${PROJECT}/src/testapp/main.py"
  # postgres + redis
  assert [ -d "${PROJECT}/src/testapp/db" ]
  assert [ -d "${PROJECT}/src/testapp/cache" ]
  # testcontainers
  assert [ -f "${PROJECT}/tests/integration/conftest.py" ]
  # uv
  grep -q "ghcr.io/astral-sh/uv" "${PROJECT}/.devcontainer/Dockerfile"
  # gitleaks
  assert [ -f "${PROJECT}/.pre-commit-config.yaml" ]
  # locust
  assert [ -f "${PROJECT}/locustfile.py" ]
  grep -Fq 'locust' "${PROJECT}/requirements-dev.txt"
}

@test "combo full_stack: compose with all services" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_mypy "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_compose "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_postgres "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_redis "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_testcontainers "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_uv "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_gitleaks "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_locust "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"

  grep -Fq "postgres" "${PROJECT}/compose.yaml"
  grep -Fq "redis" "${PROJECT}/compose.yaml"
  grep -Fq "locust" "${PROJECT}/compose.yaml"
}

@test "combo full_stack: devcontainer joins compose network" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_mypy "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_compose "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_postgres "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_redis "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_testcontainers "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_uv "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_gitleaks "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_locust "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"

  # compose network and devcontainer on same network
  grep -Fq "testapp-net" "${PROJECT}/compose.yaml"
  grep -Fq '"initializeCommand"' "${PROJECT}/.devcontainer/devcontainer.json"
  grep -Fq '"--network=testapp-net"' "${PROJECT}/.devcontainer/devcontainer.json"
}

@test "combo full_stack: devcontainer.json valid JSON" {
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_mypy "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_compose "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_azure_identity "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_postgres "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_redis "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_testcontainers "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_uv "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_gitleaks "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_locust "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"

  assert_valid_jsonc "${PROJECT}/.devcontainer/devcontainer.json"
}
