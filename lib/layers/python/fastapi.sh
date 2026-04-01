#!/usr/bin/env bash
# lib/layers/python/fastapi.sh — Layer: FastAPI + Uvicorn
# Adds FastAPI + Uvicorn, rewrites main.py with /health endpoint.

[[ -n "${_FASTAPI_SH_LOADED:-}" ]] && return 0
_FASTAPI_SH_LOADED=1

_LAYER_PHASE="framework"
_LAYER_CONFLICTS="streamlit"
_LAYER_REQUIRES=""

apply_layer_fastapi() {
  local project_path="$1"
  local name="$2"

  log "Applying layer: fastapi (API + /health)"

  local tpl_dir; tpl_dir="$(find_layer_templates_dir "python" "fastapi")"

  inject_fragment "${tpl_dir}/fragments/requirements.txt" "${project_path}/requirements.txt"
  inject_fragment "${tpl_dir}/fragments/requirements-dev.txt" "${project_path}/requirements-dev.txt"

  local main_py=""
  local import_app=""
  if [[ -d "${project_path}/src" ]]; then
    main_py="$(find "${project_path}/src" -name main.py -type f | head -n1)"
    if [[ -n "$main_py" ]] && ! grep -q 'from fastapi import FastAPI' "$main_py" 2>/dev/null; then
      local pkg_dir pkg_name
      pkg_dir="$(dirname "$main_py")"
      pkg_name="$(basename "$pkg_dir")"
      import_app="${pkg_name}.main:app"
    fi
  fi
  if [[ -z "$main_py" ]] && [[ -f "${project_path}/main.py" ]]; then
    # Idempotency: if main.py already has FastAPI, do not overwrite
    if grep -q 'from fastapi import FastAPI' "${project_path}/main.py" 2>/dev/null; then
      echo "  Layer:    fastapi (uvicorn + /health) [already applied]"
      return 0
    fi
    main_py="${project_path}/main.py"
    import_app="main:app"
  fi

  if [[ -n "$main_py" ]] && [[ -n "$import_app" ]]; then
    render_template "$tpl_dir/templates/main.py" "$main_py" "PROJECT_NAME=${name}"
    if [[ -n "$import_app" ]] && [[ "$import_app" != "main:app" ]]; then
      local sed_safe_import; sed_safe_import="$(_sed_escape "$import_app")"
      sed -i "s|uvicorn.run(\"main:app\"|uvicorn.run(\"${sed_safe_import}\"|g" "$main_py"
    fi
  fi

  if [[ -f "${project_path}/pyproject.toml" ]]; then
    if grep -Fq '[project.scripts]' "${project_path}/pyproject.toml"; then
        sed -i '/^\[project\.scripts\]/,/^\[/{/^\[project\.scripts\]/d;/^\[/!d}' "${project_path}/pyproject.toml"
    fi
  fi

  local test_file="${project_path}/tests/test_main.py"
    if [[ -f "$test_file" ]] && ! grep -q 'def test_health(client)' "$test_file" 2>/dev/null; then
    render_template "$tpl_dir/templates/tests/test_main.py" "$test_file"
  fi

  # ---- Inject client fixture into root conftest.py (marker-based) ----
  local conftest="${project_path}/tests/conftest.py"
  if [[ -f "$conftest" ]] && ! grep -Fxq 'from fastapi.testclient import TestClient' "$conftest"; then
    local import_module="main"
    if [[ -n "$import_app" ]] && [[ "$import_app" == *"."* ]]; then
      import_module="${import_app%%:*}"
    fi
    inject_fragment_at "$tpl_dir/fragments/conftest-imports.py" "$conftest" "imports" "IMPORT_APP=${import_module}"
    inject_fragment_at "$tpl_dir/fragments/conftest-fixture.py" "$conftest" "fixtures"
  fi

  # ---- README.md — update Usage section for uvicorn ----
  local readme="${project_path}/README.md"
  if [[ -f "$readme" ]] && ! grep -Fq 'uvicorn' "$readme"; then
    local use_app="${import_app:-main:app}"
    local sed_safe_app; sed_safe_app="$(_sed_escape "$use_app")"

    if grep -Fq 'python main.py' "$readme"; then
      sed -i "s|python main.py|uvicorn ${sed_safe_app} --reload|" "$readme"
    else
      # 'python main.py' was already replaced (e.g. src layout).
      # Locate the code block inside ## Usage and replace the command.
      local bash_line
      bash_line="$(awk '/^## Usage$/{f=1} f && /^```bash$/{print NR; exit}' "$readme")"
      if [[ -n "$bash_line" ]]; then
        local cmd_line=$((bash_line + 1))
        sed -i "${cmd_line}s|.*|uvicorn ${sed_safe_app} --reload|" "$readme"
      fi
    fi

    # Swagger UI note after the ## Usage code block
    if ! grep -Fq '/docs' "$readme"; then
      local close_line
      close_line="$(awk '/^## Usage$/{f=1} f && /^```$/{print NR; exit}' "$readme")"
      if [[ -n "$close_line" ]]; then
        sed -i "${close_line}a\\
\\
> Interactive API docs (Swagger UI): [http://localhost:8000/docs](http://localhost:8000/docs)" "$readme"
      fi
    fi
  fi

  if [[ -f "${project_path}/Dockerfile" ]]; then
    # Enable EXPOSE 8000 (commented out in base template)
    sed -i 's|^# EXPOSE 8000|EXPOSE 8000|' "${project_path}/Dockerfile"
    local sed_safe_app; sed_safe_app="$(_sed_escape "$import_app")"
    if grep -Fq 'CMD ["python", "main.py"]' "${project_path}/Dockerfile"; then
      sed -i "s|CMD \[\"python\", \"main.py\"\]|CMD [\"uvicorn\", \"${sed_safe_app}\", \"--host\", \"0.0.0.0\", \"--port\", \"8000\"]|" "${project_path}/Dockerfile"
    elif grep -Fq 'CMD ["' "${project_path}/Dockerfile"; then
      sed -i "s|CMD \[\"[^\"]*\"\]|CMD [\"uvicorn\", \"${sed_safe_app}\", \"--host\", \"0.0.0.0\", \"--port\", \"8000\"]|" "${project_path}/Dockerfile"
    fi
    sed -i "s|urlopen('http://localhost:8000/')|urlopen('http://localhost:8000/health')|" "${project_path}/Dockerfile"
    sed -i 's|# exec form: PID 1 = python|# exec form: PID 1 = uvicorn|' "${project_path}/Dockerfile"
  fi

  # ---- Standalone: inject app service into compose.yaml ----
  local compose_file="${project_path}/compose.yaml"
  if [[ -f "$compose_file" ]] && [[ -z "${DROPWSL_WORKSPACE:-}" ]]; then
    if ! grep -Fq '  app:' "$compose_file"; then
      local service_block
      service_block="    build: .
    profiles:
      - prod
    ports:
      - \"8000:8000\"
    environment: {}
    restart: unless-stopped"
      inject_compose_service "$project_path" "app" "$service_block"
    fi

    # ---- README.md — replace Docker (Production) section for compose ----
    local readme="${project_path}/README.md"
    if [[ -f "$readme" ]] && grep -Fq 'Docker (Production)' "$readme"; then
      if ! grep -Fq 'docker compose --profile prod' "$readme"; then
        # Find the range: from "## Docker (Production)" to the line before next "## "
        local section_start section_end next_section
        section_start="$(grep -n '^## Docker (Production)' "$readme" | head -n1 | cut -d: -f1)"
        if [[ -n "$section_start" ]]; then
          next_section="$(tail -n "+$((section_start + 1))" "$readme" | grep -n '^## ' | head -n1 | cut -d: -f1)"
          if [[ -n "$next_section" ]]; then
            section_end=$((section_start + next_section - 1))
          else
            # Last section: delete to end of file + 1 (sed handles gracefully)
            section_end=$(($(wc -l < "$readme") + 1))
          fi

          local replace_tmp; replace_tmp="$(make_temp)"
          local proj_name; proj_name="$(basename "$project_path")"
          cp "$tpl_dir/fragments/readme-docker-compose.md" "$replace_tmp"
          sed -i 's/\r$//' "$replace_tmp"
          local sed_safe_name; sed_safe_name="$(_sed_escape "$proj_name")"
          sed -i "s|{{PROJECT_NAME}}|${sed_safe_name}|g" "$replace_tmp"
          # Delete old section content (keep section_start line, delete rest)
          sed -i "$((section_start)),$((section_end - 1))d" "$readme"
          # Insert new content at section_start position
          local insert_at=$((section_start - 1))
          sed -i "${insert_at}r ${replace_tmp}" "$readme"
        fi
      fi
    fi
  fi

  # ---- Workspace: replace sleep infinity with uvicorn in compose.yaml ----
  local compose_file="${project_path}/compose.yaml"
  if [[ -f "$compose_file" ]] && grep -Fq "  ${name}:" "$compose_file"; then
    local svc_line cmd_line actual_line
    svc_line="$(grep -Fn "  ${name}:" "$compose_file" | head -n1 | cut -d: -f1)"
    if [[ -n "$svc_line" ]]; then
      cmd_line="$(tail -n "+${svc_line}" "$compose_file" | grep -n 'command: sleep infinity' | head -n1 | cut -d: -f1)"
      if [[ -n "$cmd_line" ]]; then
        actual_line=$((svc_line + cmd_line - 1))
        local sed_safe_cmd; sed_safe_cmd="$(_sed_escape "$import_app")"
        local uvicorn_args="${sed_safe_cmd} --host 0.0.0.0 --port 8000 --reload"
        if [[ -d "${project_path}/src" ]]; then
          uvicorn_args="${sed_safe_cmd} --app-dir src --host 0.0.0.0 --port 8000 --reload"
        fi
        sed -i "${actual_line}s|command: sleep infinity|command: uvicorn ${uvicorn_args}|" "$compose_file"
      fi
    fi
  fi

  echo "  Layer:    fastapi (uvicorn + /health)"
}
