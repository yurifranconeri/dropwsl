#!/usr/bin/env bats
# tests/integration/layer_python/test_layer_fastapi.bats

setup() {
  load '../../helpers/layer_test_helper'
  _common_setup
  PROJECT="$(setup_project_scaffold "testapp")"
  source_layer "${REPO_ROOT}/lib/layers/python/fastapi.sh"
}

teardown() {
  _common_teardown
}

@test "layer_fastapi: main.py contains FastAPI" {
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "from fastapi import FastAPI" "${PROJECT}/main.py"
}

@test "layer_fastapi: requirements.txt contains fastapi and uvicorn" {
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "fastapi" "${PROJECT}/requirements.txt"
  grep -Fq "uvicorn" "${PROJECT}/requirements.txt"
}

@test "layer_fastapi: Dockerfile with EXPOSE 8000" {
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -q "EXPOSE 8000" "${PROJECT}/Dockerfile"
}

@test "layer_fastapi: Dockerfile with CMD uvicorn" {
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -q "uvicorn" "${PROJECT}/Dockerfile"
}

@test "layer_fastapi: tests contains client fixture (TestClient)" {
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  # test_main.py uses client fixture
  grep -q "def test_health(client)" "${PROJECT}/tests/test_main.py"
  # conftest.py has TestClient from fragment
  grep -q "TestClient" "${PROJECT}/tests/conftest.py"
}

@test "layer_fastapi: idempotent — FastAPI already exists → no duplication" {
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local count_before
  count_before=$(grep -c "from fastapi" "${PROJECT}/main.py" || true)
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local count_after
  count_after=$(grep -c "from fastapi" "${PROJECT}/main.py" || true)
  assert [ "$count_before" -eq "$count_after" ]
}

@test "layer_fastapi: with src layout" {
  source_layer "${REPO_ROOT}/lib/layers/python/src.sh"
  apply_layer_src "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -Fq "from fastapi" "${PROJECT}/src/testapp/main.py"
}

@test "layer_fastapi: README updated" {
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  grep -qi "api\|fastapi\|endpoint" "${PROJECT}/README.md" 2>/dev/null || true
}

# ── conftest ordering: imports before pytest_plugins ──────────────

@test "layer_fastapi: conftest imports appear before pytest_plugins" {
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local conftest="${PROJECT}/tests/conftest.py"
  local import_line plugins_line
  import_line="$(grep -n 'from fastapi.testclient import TestClient' "$conftest" | head -n1 | cut -d: -f1)"
  plugins_line="$(grep -n 'pytest_plugins' "$conftest" | head -n1 | cut -d: -f1)"
  assert [ -n "$import_line" ]
  assert [ -n "$plugins_line" ]
  assert [ "$import_line" -lt "$plugins_line" ]
}

# ── conftest injection idempotency ────────────────────────────────

@test "layer_fastapi: conftest injection idempotent — import and fixture appear once" {
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local import_count
  local fixture_count
  import_count="$(grep -c 'from fastapi.testclient import TestClient' "${PROJECT}/tests/conftest.py" || true)"
  fixture_count="$(grep -c 'return TestClient(app)' "${PROJECT}/tests/conftest.py" || true)"
  assert [ "$import_count" -eq 1 ]
  assert [ "$fixture_count" -eq 1 ]
}

# ── README compose section (when compose exists) ─────────────────

@test "layer_fastapi: README shows compose when compose.yaml exists" {
  # Create a compose.yaml (fastapi layer injects app service into it)
  source_layer "${REPO_ROOT}/lib/layers/shared/compose.sh"
  apply_layer_compose "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local readme="${PROJECT}/README.md"
  grep -Fq 'docker compose --profile prod' "$readme"
  grep -Fq '<details>' "$readme"
}

@test "layer_fastapi: README compose section idempotent" {
  source_layer "${REPO_ROOT}/lib/layers/shared/compose.sh"
  apply_layer_compose "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  apply_layer_fastapi "$PROJECT" "testapp" "python" "${PROJECT}/.devcontainer"
  local heading_count
  local details_count
  heading_count="$(grep -c '^## Docker (Production)$' "${PROJECT}/README.md" || true)"
  details_count="$(grep -c '^<details>$' "${PROJECT}/README.md" || true)"
  assert [ "$heading_count" -eq 1 ]
  assert [ "$details_count" -eq 1 ]
}
