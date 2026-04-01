#!/usr/bin/env bash
# lib/layers/python/postgres.sh — Layer: PostgreSQL + SQLAlchemy 2.0
# Adds psycopg3, SQLAlchemy 2.0, models, engine, service layer and .env.example.

[[ -n "${_POSTGRES_SH_LOADED:-}" ]] && return 0
_POSTGRES_SH_LOADED=1

_LAYER_PHASE="infra"
_LAYER_CONFLICTS=""
_LAYER_REQUIRES=""

apply_layer_postgres() {
  local project_path="$1"
  local name="${2:-my-project}"
  local devcontainer_dir="${4:-${project_path}/.devcontainer}"

  log "Applying layer: postgres (SQLAlchemy 2.0 + psycopg3)"

  local package_name; package_name="$(_to_package_name "$name")"
  _detect_python_layout "$project_path" "$package_name"
  local has_src="$_HAS_SRC"
  local pkg_base="$_PKG_BASE"
  local has_api_framework="$_HAS_API_FRAMEWORK"
  local has_compose_file="$_HAS_COMPOSE"
  local has_local_infra="$_HAS_LOCAL_INFRA"
  local main_py="${pkg_base}/main.py"

  local tpl_dir; tpl_dir="$(find_layer_templates_dir "python" "postgres")"

  # ---- requirements.txt ----
  inject_fragment "${tpl_dir}/fragments/requirements.txt" "${project_path}/requirements.txt"

  # ---- Idempotency: if db/ already exists, skip generation ----
  if [[ -d "${pkg_base}/db" ]]; then
    log "Directory db/ already exists -- skipping code generation"
    echo "  Layer:    postgres (SQLAlchemy 2.0) [already applied]"
    return 0
  fi

  # ---- Create db/ package ----
  mkdir -p "${pkg_base}/db"

  # ---- db/__init__.py ----
  render_template "$tpl_dir/templates/db/__init__.py" "${pkg_base}/db/__init__.py"

  # ---- db/models.py ----
  render_template "$tpl_dir/templates/db/models.py" "${pkg_base}/db/models.py"

  # ---- db/engine.py ----
  if $has_local_infra; then
    render_template "$tpl_dir/templates/db/engine_compose.py" "${pkg_base}/db/engine.py" "DB_NAME=${name}"
  else
    render_template "$tpl_dir/templates/db/engine_standalone.py" "${pkg_base}/db/engine.py"
  fi

  # ---- db/service.py ----
  render_template "$tpl_dir/templates/db/service.py" "${pkg_base}/db/service.py"

  # ---- .env.example ----
  ensure_env_example "$project_path"
  local env_example="${project_path}/.env.example"
  if $has_local_infra; then
    inject_fragment "${tpl_dir}/fragments/env-compose.example" "$env_example" "DB_NAME=${name}"
  else
    inject_fragment "${tpl_dir}/fragments/env-standalone.example" "$env_example"
  fi

  # ---- Inject compose service (only if compose.yaml already exists) ----
  # If compose.yaml does not exist, only generates .env.example (bring your own DB).
  if $has_local_infra && [[ -f "${project_path}/compose.yaml" ]]; then
    _inject_postgres_compose_service "$project_path" "$name"
    # Augments app service with DATABASE_URL + depends_on (if app: exists in compose)
    if [[ -z "${DROPWSL_WORKSPACE:-}" ]]; then
      _augment_app_with_postgres "$project_path" "$name"
    fi
  fi

  # ---- main.py — if API framework, inject DB via sed; if standalone, replace ----
  if $has_api_framework; then
    _inject_postgres_into_api "$project_path" "$name" "$package_name" "$has_src" "$has_local_infra"
  elif [[ -f "${pkg_base}/main.py" ]] && grep -q '^def main' "${pkg_base}/main.py" 2>/dev/null; then
    # main.py still has bare entry point (original scaffold) — safe to replace
    _inject_postgres_standalone "$project_path" "$package_name" "$has_src"
  fi

  # ---- Fixtures + unit tests (tests/fixtures/db.py + tests/unit/) ----
  _inject_postgres_fixtures "$project_path" "$package_name" "$has_src" "$has_api_framework" "$has_local_infra"
  _inject_postgres_unit_tests "$project_path" "$package_name" "$has_src"

  # ---- VS Code extensions (SQLTools) ----
  inject_vscode_extension "${devcontainer_dir}/devcontainer.json" "mtxr.sqltools"
  inject_vscode_extension "${devcontainer_dir}/devcontainer.json" "mtxr.sqltools-driver-pg"

  # ---- README.md — Database section + update structure ----
  local readme="${project_path}/README.md"
  if [[ -f "$readme" ]]; then
    # Add Database section before Docker (Production)
    if ! grep -Fq '## Database' "$readme"; then
      local db_section="## Database

The project uses **PostgreSQL** via SQLAlchemy 2.0 + psycopg3.

\`\`\`bash
# Environment variables (copy .env.example → .env)
cp .env.example .env

# If using compose:
docker compose up -d

# Tables are created automatically on startup (create_all)
\`\`\`

Database structure:

- \`db/models.py\` — SQLAlchemy models (tables)
- \`db/engine.py\` — Engine, session management, \`DATABASE_URL\`
- \`db/service.py\` — CRUD functions (service layer)

> In production, use [Alembic](https://alembic.sqlalchemy.org/) for migrations.
"
      if grep -q '^## Docker' "$readme"; then
        local docker_line
        docker_line="$(grep -n '^## Docker' "$readme" | head -n1 | cut -d: -f1)"
        local tmp
        tmp="$(make_temp)"
        head -n "$((docker_line - 1))" "$readme" > "$tmp"
        echo "$db_section" >> "$tmp"
        tail -n "+${docker_line}" "$readme" >> "$tmp"
        mv "$tmp" "$readme"
      else
        echo "$db_section" >> "$readme"
      fi
    fi

    # Update structure tree — add db/
    if ! grep -Fq '# Database (models' "$readme"; then
      if grep -Fq 'Source code' "$readme"; then
        sed -i '/Source code/i\├── db/                   # Database (models, engine, service)' "$readme"
      elif grep -Fq 'Entry point' "$readme"; then
        sed -i '/Entry point/i\├── db/                   # Database (models, engine, service)' "$readme"
      fi
    fi
  fi

  echo "  Layer:    postgres (SQLAlchemy 2.0 + psycopg3)"
}

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

_inject_postgres_compose_service() {
  local project_path="$1"
  local name="$2"

  # If compose.yaml exists (or will be created by compose layer), inject service
  # inject_compose_service creates the skeleton if needed
  local service_block
  service_block="    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      POSTGRES_USER: \${POSTGRES_USER:-postgres}
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD:-changeme}
      POSTGRES_DB: \${POSTGRES_DB:-${name}}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: [\"CMD-SHELL\", \"pg_isready -U \$\$POSTGRES_USER -d \$\$POSTGRES_DB\"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s"

  local volume_block="  postgres_data:"

  inject_compose_service "$project_path" "postgres" "$service_block" "$volume_block"
}

_augment_app_with_postgres() {
  local project_path="$1"
  local name="$2"

  local compose_file="${project_path}/compose.yaml"
  [[ -f "$compose_file" ]] || return 0
  grep -Fq '  app:' "$compose_file" || return 0

  # Add DATABASE_URL to the app environment
  if ! grep -Fq 'DATABASE_URL' "$compose_file"; then
    # Expand environment: {} -> environment: (if needed)
    sed -i '/^  app:/,/^  [a-z]/{s/    environment: {}/    environment:/}' "$compose_file"
    local env_line
    env_line="$(sed -n '/^  app:/,/^  [a-z]/{ /environment:/= }' "$compose_file" | head -n1)"
    if [[ -n "$env_line" ]]; then
      sed -i "${env_line}a\\      DATABASE_URL: postgresql+psycopg://\${POSTGRES_USER:-postgres}:\${POSTGRES_PASSWORD:-changeme}@postgres:5432/\${POSTGRES_DB:-${name}}" "$compose_file"
    fi
  fi

  # Add depends_on postgres
  if ! grep -Fq 'depends_on:' "$compose_file"; then
    # No depends_on — insert before restart in app block
    local restart_line
    restart_line="$(sed -n '/^  app:/,/^  [a-z]/{ /restart:/= }' "$compose_file" | head -n1)"
    if [[ -n "$restart_line" ]]; then
      sed -i "${restart_line}i\\    depends_on:" "$compose_file"
      sed -i "$((restart_line + 1))i\\      postgres:" "$compose_file"
      sed -i "$((restart_line + 2))i\\        condition: service_healthy" "$compose_file"
    fi
  else
    # depends_on already exists -- add postgres entry (if not present)
    if ! grep -Fq '      postgres:' "$compose_file"; then
      local dep_line
      dep_line="$(sed -n '/^  app:/,/^  [a-z]/{ /depends_on:/= }' "$compose_file" | head -n1)"
      if [[ -n "$dep_line" ]]; then
        sed -i "${dep_line}a\\      postgres:" "$compose_file"
        sed -i "$((dep_line + 1))a\\        condition: service_healthy" "$compose_file"
      fi
    fi
  fi
}

_inject_postgres_into_api() {
  local project_path="$1"
  local name="$2"
  local package_name="$3"
  local has_src="$4"
  local has_local_infra="${5:-false}"

  # Locate main.py
  local main_py=""
  if [[ "$has_src" == true ]]; then
    main_py="${project_path}/src/${package_name}/main.py"
  else
    main_py="${project_path}/main.py"
  fi
  [[ -f "$main_py" ]] || return 0

  # Idempotency: if already has SQLAlchemy imports, skip
  if grep -q 'from.*db.engine import' "$main_py" 2>/dev/null; then
    return 0
  fi

  # Determina import prefix
  local import_prefix=""
  if [[ "$has_src" == true ]]; then
    import_prefix="${package_name}."
  fi

  local tpl_dir; tpl_dir="$(find_layer_templates_dir "python" "postgres")"

  # --- 1. Replace `from fastapi import FastAPI` with full imports block ---
  local imports_tmp; imports_tmp="$(make_temp)"
  sed "s|{{IMPORT_PREFIX}}|${import_prefix}|g" "$tpl_dir/fragments/main-imports.py" > "$imports_tmp"
  sed -i 's/\r$//' "$imports_tmp"

  local target_line
  target_line="$(grep -Fn 'from fastapi import FastAPI' "$main_py" | head -n1 | cut -d: -f1)"
  if [[ -n "$target_line" ]]; then
    sed -i "${target_line}r ${imports_tmp}" "$main_py"
    sed -i "${target_line}d" "$main_py"
  fi

  # --- 2. Insert schemas BEFORE `app = FastAPI(` ---
  local schemas_tmp; schemas_tmp="$(make_temp)"
  cp "$tpl_dir/fragments/main-schemas.py" "$schemas_tmp"
  sed -i 's/\r$//' "$schemas_tmp"

  target_line="$(grep -Fn 'app = FastAPI(' "$main_py" | head -n1 | cut -d: -f1)"
  if [[ -n "$target_line" ]]; then
    local before_line=$((target_line - 1))
    sed -i "${before_line}r ${schemas_tmp}" "$main_py"
  fi

  # --- 3. Insert lifespan BEFORE `app = FastAPI(` (line numbers shifted) ---
  local lifespan_tmp; lifespan_tmp="$(make_temp)"
  cp "$tpl_dir/fragments/main-lifespan.py" "$lifespan_tmp"
  sed -i 's/\r$//' "$lifespan_tmp"

  # Without compose: adjust lifespan warning (remove docker compose hint)
  if [[ "$has_local_infra" != true ]]; then
    sed -i "s|Run 'docker compose up -d'.|Configure DATABASE_URL in .env.|" "$lifespan_tmp"
  fi

  target_line="$(grep -Fn 'app = FastAPI(' "$main_py" | head -n1 | cut -d: -f1)"
  if [[ -n "$target_line" ]]; then
    local before_line=$((target_line - 1))
    sed -i "${before_line}r ${lifespan_tmp}" "$main_py"
  fi

  # --- 3.5. Extend health check to include PostgreSQL ---
  _inject_postgres_health "$main_py" "$tpl_dir"

  # --- 4. Add lifespan= to FastAPI constructor ---
  local sed_safe_name; sed_safe_name="$(_sed_escape "$name")"
  sed -i "s|app = FastAPI(title=\"${sed_safe_name}\", version=\"0.1.0\")|app = FastAPI(title=\"${sed_safe_name}\", version=\"0.1.0\", lifespan=lifespan)|" "$main_py"

  # --- 5. Insert CRUD routes BEFORE `if __name__` ---
  local routes_tmp; routes_tmp="$(make_temp)"
  cp "$tpl_dir/fragments/main-routes-crud.py" "$routes_tmp"
  sed -i 's/\r$//' "$routes_tmp"

  target_line="$(grep -Fn 'if __name__' "$main_py" | head -n1 | cut -d: -f1)"
  if [[ -n "$target_line" ]]; then
    local before_line=$((target_line - 1))
    sed -i "${before_line}r ${routes_tmp}" "$main_py"
  fi

  # Add pydantic-settings to deps (if not present)
  inject_fragment "${tpl_dir}/fragments/requirements-pydantic.txt" "${project_path}/requirements.txt"
}

_inject_postgres_health() {
  local main_py="$1"
  local tpl_dir="$2"

  [[ -f "$main_py" ]] || return 0
  grep -Fq 'health_status["postgres"]' "$main_py" && return 0

  local marker_line
  marker_line="$(grep -Fn '# -- dropwsl:health-checks --' "$main_py" | head -n1 | cut -d: -f1)"
  if [[ -n "$marker_line" ]]; then
    local health_tmp; health_tmp="$(make_temp)"
    cp "$tpl_dir/fragments/main-health-postgres.py" "$health_tmp"
    sed -i 's/\r$//' "$health_tmp"
    sed -i "${marker_line}r ${health_tmp}" "$main_py"
    return 0
  fi

  local return_line
  return_line="$(grep -Fn 'return {"status": "ok"}' "$main_py" | head -n1 | cut -d: -f1)"
  if [[ -n "$return_line" ]]; then
    local fallback_tmp; fallback_tmp="$(make_temp)"
    cp "$tpl_dir/fragments/main-health-postgres-fallback.py" "$fallback_tmp"
    sed -i 's/\r$//' "$fallback_tmp"
    sed -i "${return_line}r ${fallback_tmp}" "$main_py"
    sed -i "${return_line}d" "$main_py"
  fi
}

_inject_postgres_standalone() {
  local project_path="$1"
  local package_name="$2"
  local has_src="$3"

  # Locate main.py
  local main_py=""
  if [[ "$has_src" == true ]]; then
    main_py="${project_path}/src/${package_name}/main.py"
  else
    main_py="${project_path}/main.py"
  fi
  [[ -f "$main_py" ]] || return 0

  # Idempotency: if already has SQLAlchemy imports, skip
  if grep -q 'from.*db.engine import' "$main_py" 2>/dev/null; then
    return 0
  fi

  # Determine import prefix
  local import_prefix=""
  if [[ "$has_src" == true ]]; then
    import_prefix="${package_name}."
  fi

  local tpl_dir; tpl_dir="$(find_layer_templates_dir "python" "postgres")"
  render_template "$tpl_dir/templates/main_standalone.py" "$main_py" \
    "IMPORT_PREFIX=${import_prefix}"
}

_inject_postgres_fixtures() {
  local project_path="$1"
  local package_name="$2"
  local has_src="$3"
  local has_api_framework="$4"
  local has_local_infra="${5:-false}"

  local fixtures_dir="${project_path}/tests/fixtures"
  mkdir -p "$fixtures_dir"
  [[ -f "${fixtures_dir}/__init__.py" ]] || touch "${fixtures_dir}/__init__.py"

  # Idempotency: if db.py already exists, skip
  local fixtures_file="${fixtures_dir}/db.py"
  if [[ -f "$fixtures_file" ]]; then
    return 0
  fi

  local import_prefix=""
  if [[ "$has_src" == true ]]; then
    import_prefix="${package_name}."
  fi

  local tpl_dir; tpl_dir="$(find_layer_templates_dir "python" "postgres")"

  if $has_api_framework; then
    render_template "$tpl_dir/templates/tests/fixtures/db_api.py" "$fixtures_file" \
      "IMPORT_PREFIX=${import_prefix}"
  else
    render_template "$tpl_dir/templates/tests/fixtures/db_standalone.py" "$fixtures_file" \
      "IMPORT_PREFIX=${import_prefix}"
  fi

  # Without compose: inject DATABASE_URL at top of fixture (avoids RuntimeError on engine import)
  if [[ "$has_local_infra" != true ]]; then
    local env_tmp; env_tmp="$(make_temp)"
    cp "$tpl_dir/fragments/fixture-env-database-url.py" "$env_tmp"
    local doc_line
    doc_line="$(grep -Fn '"""Database fixtures' "$fixtures_file" | head -n1 | cut -d: -f1)"
    if [[ -n "$doc_line" ]]; then
      sed -i "${doc_line}r ${env_tmp}" "$fixtures_file"
    fi
  fi

  # Inject pytest_plugins entry in root conftest.py
  local conftest="${project_path}/tests/conftest.py"
  if [[ -f "$conftest" ]] && ! grep -Fq 'tests.fixtures.db' "$conftest"; then
    sed -i '/# -- dropwsl:plugins --/a\    "tests.fixtures.db",' "$conftest"
  fi
}

_inject_postgres_unit_tests() {
  local project_path="$1"
  local package_name="$2"
  local has_src="$3"

  local test_dir="${project_path}/tests/unit"
  mkdir -p "$test_dir"
  # __init__.py for pytest discovery
  [[ -f "${test_dir}/__init__.py" ]] || touch "${test_dir}/__init__.py"

  # test_db.py -- unit tests for the service layer (mock Session)
  local test_file="${test_dir}/test_db.py"
  if [[ -f "$test_file" ]]; then
    return 0
  fi

  local import_prefix=""
  if [[ "$has_src" == true ]]; then
    import_prefix="${package_name}."
  fi

  local tpl_dir; tpl_dir="$(find_layer_templates_dir "python" "postgres")"
  render_template "$tpl_dir/templates/tests/test_db.py" "$test_file" "IMPORT_PREFIX=${import_prefix}"
}
