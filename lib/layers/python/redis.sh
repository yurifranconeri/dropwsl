#!/usr/bin/env bash
# lib/layers/python/redis.sh — Layer: Redis (cache + sessions)
# Adds redis client, cache/ package, compose service and .env.example.

[[ -n "${_REDIS_SH_LOADED:-}" ]] && return 0
_REDIS_SH_LOADED=1

_LAYER_PHASE="infra-inject"
_LAYER_CONFLICTS=""
_LAYER_REQUIRES=""

apply_layer_redis() {
  local project_path="$1"
  local name="${2:-my-project}"
  local devcontainer_dir="${4:-${project_path}/.devcontainer}"

  log "Applying layer: redis (cache + sessions)"

  local package_name; package_name="$(_to_package_name "$name")"
  _detect_python_layout "$project_path" "$package_name"
  local has_src="$_HAS_SRC"
  local pkg_base="$_PKG_BASE"
  local has_async_api="$_HAS_API_FRAMEWORK"
  local has_compose_file="$_HAS_COMPOSE"
  local has_local_infra="$_HAS_LOCAL_INFRA"

  local tpl_dir; tpl_dir="$(find_layer_templates_dir "python" "redis")"

  # ---- requirements.txt ----
  inject_fragment "${tpl_dir}/fragments/requirements.txt" "${project_path}/requirements.txt"

  # ---- Idempotency: if cache/ already exists, skip generation ----
  if [[ -d "${pkg_base}/cache" ]]; then
    log "Directory cache/ already exists -- skipping code generation"
    echo "  Layer:    redis (cache) [already applied]"
    return 0
  fi

  # ---- Create cache/ package ----
  mkdir -p "${pkg_base}/cache"

  # ---- cache/__init__.py ----
  render_template "$tpl_dir/templates/cache/__init__.py" "${pkg_base}/cache/__init__.py"

  # ---- cache/client.py ----
  local import_prefix=""
  if [[ "$has_src" == true ]]; then
    import_prefix="${package_name}."
  fi

  if $has_async_api; then
    # Async client (API framework detected)
    render_template "$tpl_dir/templates/cache/client_async.py" "${pkg_base}/cache/client.py"
  else
    # Sync client (no async API)
    render_template "$tpl_dir/templates/cache/client_sync.py" "${pkg_base}/cache/client.py"
  fi

  # Without compose: replace REDIS_URL default with RuntimeError
  if [[ "$has_local_infra" != true ]]; then
    local redis_url_tmp; redis_url_tmp="$(make_temp)"
    cp "$tpl_dir/fragments/client-redis-url-nocompose.py" "$redis_url_tmp"
    local target_line
    target_line="$(grep -Fn 'REDIS_URL = os.getenv' "${pkg_base}/cache/client.py" | head -n1 | cut -d: -f1)"
    if [[ -n "$target_line" ]]; then
      sed -i "${target_line}r ${redis_url_tmp}" "${pkg_base}/cache/client.py"
      sed -i "${target_line}d" "${pkg_base}/cache/client.py"
    fi
  fi

  # ---- .env.example ----
  ensure_env_example "$project_path"
  local env_example="${project_path}/.env.example"
  if $has_local_infra; then
    inject_fragment "${tpl_dir}/fragments/env-compose.example" "$env_example"
  else
    inject_fragment "${tpl_dir}/fragments/env-standalone.example" "$env_example"
  fi

  # ---- Inject compose service (only if compose.yaml already exists) ----
  if $has_local_infra && [[ -f "${project_path}/compose.yaml" ]]; then
    _inject_redis_compose_service "$project_path"
  fi

  # ---- Async API: inject Redis health check into main.py ----
  if $has_async_api; then
    _inject_redis_api "$project_path" "$package_name" "$has_src"
  fi

  # ---- VS Code extensions (Redis client) ----
  inject_vscode_extension "${devcontainer_dir}/devcontainer.json" "cweijan.vscode-redis-client"

  # ---- Fixtures + unit tests ----
  _inject_redis_fixtures "$project_path" "$package_name" "$has_src" "$has_async_api" "$has_local_infra"
  _inject_redis_unit_tests "$project_path" "$package_name" "$has_src" "$has_async_api" "$has_local_infra"

  # Without compose: inject REDIS_URL env into root conftest.py via fragment
  if [[ "$has_local_infra" != true ]]; then
    inject_fragment_at "${tpl_dir}/fragments/conftest-env-redis.py" "${project_path}/tests/conftest.py" "imports"
  fi

  # ---- README.md — Cache section + update structure ----
  local readme="${project_path}/README.md"
  if [[ -f "$readme" ]]; then
    # Add Cache (Redis) section before Docker (Production)
    if ! grep -Fq 'Cache (Redis)' "$readme"; then
      local cache_section="## Cache (Redis)

The project uses **Redis** for cache and sessions.

\`\`\`bash
# If using compose:
docker compose up -d redis

# Test connectivity
docker compose exec redis redis-cli PING
\`\`\`

Cache structure:

- \`cache/client.py\` — Redis client, \`REDIS_URL\`, health check
- \`cache/__init__.py\` — Re-exports

> In production, configure \`REDIS_URL\` via environment variables.
"
      if grep -q '^## Docker' "$readme"; then
        local docker_line
        docker_line="$(grep -n '^## Docker' "$readme" | head -n1 | cut -d: -f1)"
        local tmp
        tmp="$(make_temp)"
        head -n "$((docker_line - 1))" "$readme" > "$tmp"
        echo "$cache_section" >> "$tmp"
        tail -n "+${docker_line}" "$readme" >> "$tmp"
        mv "$tmp" "$readme"
      else
        echo "$cache_section" >> "$readme"
      fi
    fi

    # Update structure tree — add cache/
    if ! grep -Fq '# Cache (Redis client' "$readme"; then
      if grep -Fq 'Database (models' "$readme"; then
        sed -i '/Database (models/i\├── cache/                  # Cache (Redis client, health check)' "$readme"
      elif grep -Fq 'Source code' "$readme"; then
        sed -i '/Source code/i\├── cache/                  # Cache (Redis client, health check)' "$readme"
      elif grep -Fq 'Entry point' "$readme"; then
        sed -i '/Entry point/i\├── cache/                  # Cache (Redis client, health check)' "$readme"
      fi
    fi
  fi

  echo "  Layer:    redis (cache + sessions)"
}

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

_inject_redis_compose_service() {
  local project_path="$1"

  local service_block
  service_block="    image: redis:7-alpine
    restart: unless-stopped
    volumes:
      - redis_data:/data
    healthcheck:
      test: [\"CMD\", \"redis-cli\", \"ping\"]
      interval: 10s
      timeout: 5s
      retries: 5"

  local volume_block="  redis_data:"

  inject_compose_service "$project_path" "redis" "$service_block" "$volume_block"

  # If app service already exists (created by fastapi) AND NOT workspace, add REDIS_URL
  local compose_file="${project_path}/compose.yaml"
  if [[ -z "${DROPWSL_WORKSPACE:-}" ]] && grep -Fq '  app:' "$compose_file"; then
    if ! grep -Fq 'REDIS_URL' "$compose_file"; then
      # Expand environment: {} -> environment: (if needed)
      sed -i '/^  app:/,/^  [a-z]/{s/    environment: {}/    environment:/}' "$compose_file"
      local env_line
      env_line="$(sed -n '/^  app:/,/^  [a-z]/{ /environment:/= }' "$compose_file" | head -n1)"
      if [[ -n "$env_line" ]]; then
        sed -i "${env_line}a\\      REDIS_URL: redis://redis:6379/0" "$compose_file"
      fi
    fi
    # Add depends_on redis
    if ! grep -Fq 'depends_on:' "$compose_file"; then
      # No depends_on — insert before restart in app block
      local restart_line
      restart_line="$(sed -n '/^  app:/,/^  [a-z]/{ /restart:/= }' "$compose_file" | head -n1)"
      if [[ -n "$restart_line" ]]; then
        sed -i "${restart_line}i\\    depends_on:" "$compose_file"
        sed -i "$((restart_line + 1))i\\      redis:" "$compose_file"
        sed -i "$((restart_line + 2))i\\        condition: service_healthy" "$compose_file"
      fi
    elif ! grep -Fq '      redis:' "$compose_file"; then
      # depends_on exists — add redis entry
      local last_condition
      last_condition="$(sed -n '/^  app:/,/^  [a-z]/{ /condition: service_healthy/= }' "$compose_file" | tail -n1)"
      if [[ -n "$last_condition" ]]; then
        sed -i "${last_condition}a\\      redis:" "$compose_file"
        sed -i "$((last_condition + 1))a\\        condition: service_healthy" "$compose_file"
      else
        local dep_line
        dep_line="$(sed -n '/^  app:/,/^  [a-z]/{ /depends_on:/= }' "$compose_file" | head -n1)"
        if [[ -n "$dep_line" ]]; then
          sed -i "${dep_line}a\\      redis:" "$compose_file"
          sed -i "$((dep_line + 1))a\\        condition: service_healthy" "$compose_file"
        fi
      fi
    fi
  fi
}

_inject_redis_api() {
  local project_path="$1"
  local package_name="$2"
  local has_src="$3"

  local tpl_dir; tpl_dir="$(find_layer_templates_dir "python" "redis")"

  # Localiza main.py
  local main_py=""
  if [[ "$has_src" == true ]]; then
    main_py="${project_path}/src/${package_name}/main.py"
  else
    main_py="${project_path}/main.py"
  fi
  [[ -f "$main_py" ]] || return 0

  # Idempotency: if already has redis imports, skip
  if grep -Fq 'redis_health' "$main_py"; then
    return 0
  fi

  local import_prefix=""
  if [[ "$has_src" == true ]]; then
    import_prefix="${package_name}."
  fi

  # Inject import at top (before db imports -- cache < db alphabetically)
  if grep -Fq "from ${import_prefix}db" "$main_py"; then
    local first_db_import
    first_db_import="$(grep -n "from ${import_prefix}db" "$main_py" | head -n1 | cut -d: -f1)"
    sed -i "${first_db_import}i\from ${import_prefix}cache.client import get_redis, redis_health" "$main_py"
  else
    # No db imports -- insert after "from fastapi import"
    local fastapi_import
    fastapi_import="$(grep -n 'from fastapi import' "$main_py" | head -n1 | cut -d: -f1)"
    if [[ -n "$fastapi_import" ]]; then
      # Need a blank line before local import
      local redis_import_tmp; redis_import_tmp="$(make_temp)"
      render_template "$tpl_dir/fragments/main-import-cache.py" "$redis_import_tmp" "IMPORT_PREFIX=${import_prefix}"
      sed -i "${fastapi_import}r ${redis_import_tmp}" "$main_py"
    fi
  fi

  # Ensure Depends is imported from fastapi
  if ! grep -q 'Depends' "$main_py"; then
    sed -i 's|from fastapi import FastAPI|from fastapi import Depends, FastAPI|' "$main_py"
  fi

  # Add import redis.asyncio (for type hint -- bare import before from)
  if ! grep -Fq 'import redis.asyncio' "$main_py"; then
    local first_thirdparty
    first_thirdparty="$(grep -nE 'from (fastapi|pydantic|sqlalchemy) ' "$main_py" | head -n1 | cut -d: -f1)"
    if [[ -n "$first_thirdparty" ]]; then
      sed -i "${first_thirdparty}i\import redis.asyncio as aioredis" "$main_py"
    fi
  fi

  # Extend health check to include Redis
  _inject_redis_health "$main_py" "$tpl_dir"

  # ---- Inject example /cache routes (GET + PUT + DELETE) ----
  if ! grep -Fq '/cache' "$main_py"; then
    local routes_tmp; routes_tmp="$(make_temp)"
    cp "$tpl_dir/fragments/main-routes-cache.py" "$routes_tmp"

    # Insert before `if __name__` block
    local main_block_line
    main_block_line="$(grep -Fn 'if __name__' "$main_py" | head -n1 | cut -d: -f1)"
    if [[ -n "$main_block_line" ]]; then
      sed -i "$((main_block_line - 1))r ${routes_tmp}" "$main_py"
    else
      # If no if __name__, insert at end
      cat "$routes_tmp" >> "$main_py"
    fi
  fi
}

_inject_redis_health() {
  local main_py="$1"
  local tpl_dir="$2"

  [[ -f "$main_py" ]] || return 0
  grep -Fq 'health_status["redis"]' "$main_py" && return 0

  local marker_line
  marker_line="$(grep -Fn '# -- dropwsl:health-checks --' "$main_py" | head -n1 | cut -d: -f1)"
  if [[ -n "$marker_line" ]]; then
    local health_tmp; health_tmp="$(make_temp)"
    cp "$tpl_dir/fragments/main-health-redis.py" "$health_tmp"
    sed -i 's/\r$//' "$health_tmp"
    sed -i "${marker_line}r ${health_tmp}" "$main_py"
  else
    local return_line
    return_line="$(grep -Fn 'return {"status": "ok"}' "$main_py" | head -n1 | cut -d: -f1)"
    if [[ -n "$return_line" ]]; then
      local fallback_tmp; fallback_tmp="$(make_temp)"
      cp "$tpl_dir/fragments/main-health-redis-fallback.py" "$fallback_tmp"
      sed -i 's/\r$//' "$fallback_tmp"
      sed -i "${return_line}r ${fallback_tmp}" "$main_py"
      sed -i "${return_line}d" "$main_py"
    fi
  fi

  if ! grep -q 'async def health' "$main_py"; then
    sed -i 's|def health()|async def health()|' "$main_py"
  fi
}

_inject_redis_fixtures() {
  local project_path="$1"
  local package_name="$2"
  local has_src="$3"
  local has_async_api="$4"
  local has_local_infra="${5:-false}"

  local fixtures_dir="${project_path}/tests/fixtures"
  mkdir -p "$fixtures_dir"
  [[ -f "${fixtures_dir}/__init__.py" ]] || touch "${fixtures_dir}/__init__.py"

  # Idempotency: if cache.py already exists, skip
  local fixtures_file="${fixtures_dir}/cache.py"
  if [[ -f "$fixtures_file" ]]; then
    return 0
  fi

  local import_prefix=""
  if [[ "$has_src" == true ]]; then
    import_prefix="${package_name}."
  fi

  local tpl_dir; tpl_dir="$(find_layer_templates_dir "python" "redis")"

  if $has_async_api; then
    render_template "$tpl_dir/templates/tests/fixtures/cache_async.py" "$fixtures_file" \
      "IMPORT_PREFIX=${import_prefix}"
  else
    render_template "$tpl_dir/templates/tests/fixtures/cache_sync.py" "$fixtures_file" \
      "IMPORT_PREFIX=${import_prefix}"
  fi

  # Inject pytest_plugins entry in root conftest.py
  local conftest="${project_path}/tests/conftest.py"
  if [[ -f "$conftest" ]] && ! grep -Fq 'tests.fixtures.cache' "$conftest"; then
    sed -i '/# -- dropwsl:plugins --/a\    "tests.fixtures.cache",' "$conftest"
  fi
}

_inject_redis_unit_tests() {
  local project_path="$1"
  local package_name="$2"
  local has_src="$3"
  local has_async_api="$4"
  local has_local_infra="${5:-false}"

  local test_dir="${project_path}/tests/unit"
  mkdir -p "$test_dir"
  [[ -f "${test_dir}/__init__.py" ]] || touch "${test_dir}/__init__.py"

  local test_file="${test_dir}/test_cache.py"
  if [[ -f "$test_file" ]]; then
    return 0
  fi

  local import_prefix=""
  if [[ "$has_src" == true ]]; then
    import_prefix="${package_name}."
  fi

  if $has_async_api; then
    # Async client -- tests with AsyncMock + await
    local tpl_dir; tpl_dir="$(find_layer_templates_dir "python" "redis")"
    render_template "$tpl_dir/templates/tests/test_cache_async.py" "$test_file" "IMPORT_PREFIX=${import_prefix}"

    # Add pytest-asyncio and httpx to requirements-dev
    inject_fragment "${tpl_dir}/fragments/requirements-dev-asyncio.txt" "${project_path}/requirements-dev.txt"
    inject_fragment "${tpl_dir}/fragments/requirements-dev-httpx.txt" "${project_path}/requirements-dev.txt"

    # Configure asyncio_mode = "auto" in pyproject.toml
    if [[ -f "${project_path}/pyproject.toml" ]]; then
      if ! grep -Fq 'asyncio_mode' "${project_path}/pyproject.toml"; then
        sed -i '/\[tool\.pytest\.ini_options\]/a\asyncio_mode = "auto"' "${project_path}/pyproject.toml"
      fi
    fi
  else
    # Sync client -- tests with MagicMock, no await
    local tpl_dir; tpl_dir="$(find_layer_templates_dir "python" "redis")"
    render_template "$tpl_dir/templates/tests/test_cache_sync.py" "$test_file" "IMPORT_PREFIX=${import_prefix}"
  fi

  # Without compose: inject REDIS_URL env setdefault at top of test_cache.py
  if [[ "$has_local_infra" != true ]]; then
    local renv_tmp; renv_tmp="$(make_temp)"
    cp "$tpl_dir/fragments/conftest-env-redis.py" "$renv_tmp"
    local doc_line
    doc_line="$(grep -Fn '"""Unit tests' "$test_file" | head -n1 | cut -d: -f1)"
    if [[ -n "$doc_line" ]]; then
      sed -i "${doc_line}r ${renv_tmp}" "$test_file"
    fi
  fi
}
