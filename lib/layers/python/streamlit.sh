#!/usr/bin/env bash
# lib/layers/python/streamlit.sh — Layer: Streamlit (full showcase)
# Adds Streamlit, rewrites main.py with a showcase of all components,
# creates .streamlit/config.toml, adjusts CMD and EXPOSE in Dockerfile.

[[ -n "${_STREAMLIT_SH_LOADED:-}" ]] && return 0
_STREAMLIT_SH_LOADED=1

_LAYER_PHASE="framework"
_LAYER_CONFLICTS="fastapi"
_LAYER_REQUIRES=""

apply_layer_streamlit() {
  local project_path="$1"
  local name="$2"
  local lang="$3"
  local devcontainer_dir="${4:-${project_path}/.devcontainer}"

  log "Applying layer: streamlit (full showcase, port 8501)"

  # ---- 1. Dependencies ----
  local tpl_dir; tpl_dir="$(find_layer_templates_dir "python" "streamlit")"
  inject_fragment "${tpl_dir}/fragments/requirements.txt" "${project_path}/requirements.txt"

  # ---- 2. .streamlit/config.toml (no-clobber) ----
  local streamlit_dir="${project_path}/.streamlit"
  if [[ ! -f "${streamlit_dir}/config.toml" ]]; then
    render_template "$tpl_dir/templates/.streamlit/config.toml" "${streamlit_dir}/config.toml"
  fi

  # ---- 3. Reescreve main.py (full showcase) ----
  local main_py=""
  local run_path="main.py"
  if [[ -d "${project_path}/src" ]]; then
    main_py="$(find "${project_path}/src" -name main.py -type f | head -n1)"
    if [[ -n "$main_py" ]]; then
      local pkg_dir pkg_name
      pkg_dir="$(dirname "$main_py")"
      pkg_name="$(basename "$pkg_dir")"
      run_path="src/${pkg_name}/main.py"
    fi
  fi
  if [[ -z "$main_py" ]] && [[ -f "${project_path}/main.py" ]]; then
    main_py="${project_path}/main.py"
    run_path="main.py"
  fi

  if [[ -n "$main_py" ]]; then
    # Idempotency: if main.py already has Streamlit, do not overwrite
    if grep -q 'import streamlit' "$main_py" 2>/dev/null; then
      echo "  Layer:    streamlit (full showcase, port 8501) [already applied]"
      return 0
    fi

    render_template "$tpl_dir/templates/main.py" "$main_py" "PROJECT_NAME=${name}"
  fi

  # ---- 5. Dockerfile: CMD, EXPOSE, HEALTHCHECK ----
  if [[ -f "${project_path}/Dockerfile" ]]; then
    # Enable EXPOSE 8501 (replaces the commented 8000 from template)
    sed -i 's|^# EXPOSE 8000|EXPOSE 8501|' "${project_path}/Dockerfile"

    # CMD: python main.py → streamlit run
    local sed_safe_run; sed_safe_run="$(_sed_escape "$run_path")"
    if grep -Fq 'CMD ["python", "main.py"]' "${project_path}/Dockerfile"; then
      sed -i "s|CMD \[\"python\", \"main.py\"\]|CMD [\"streamlit\", \"run\", \"${sed_safe_run}\", \"--server.port=8501\", \"--server.address=0.0.0.0\"]|" "${project_path}/Dockerfile"
    elif grep -Fq 'CMD ["' "${project_path}/Dockerfile"; then
      # src layer already replaced CMD with the CLI entry point — overwrite
      sed -i "s|CMD \[\"[^\"]*\"\]|CMD [\"streamlit\", \"run\", \"${sed_safe_run}\", \"--server.port=8501\", \"--server.address=0.0.0.0\"]|" "${project_path}/Dockerfile"
    fi

    # HEALTHCHECK: adjust URL for Streamlit built-in health
    sed -i "s|urlopen('http://localhost:8000/')|urlopen('http://localhost:8501/_stcore/health')|" "${project_path}/Dockerfile"

    # PID 1 comment
    sed -i 's|# exec form: PID 1 = python|# exec form: PID 1 = streamlit|' "${project_path}/Dockerfile"
  fi

  # ---- 5a. Standalone: inject app service into compose.yaml ----
  local compose_file="${project_path}/compose.yaml"
  if [[ -f "$compose_file" ]] && [[ -z "${DROPWSL_WORKSPACE:-}" ]]; then
    if ! grep -Fq '  app:' "$compose_file"; then
      local service_block
      service_block="    build: .
    profiles:
      - prod
    ports:
      - \"8501:8501\"
    environment: {}
    restart: unless-stopped"
      inject_compose_service "$project_path" "app" "$service_block"
    fi
  fi

  # ---- 5b. Workspace: fix port and command in compose.yaml ----
  if [[ -f "$compose_file" ]] && grep -Fq "  ${name}:" "$compose_file"; then
    local svc_line port_line cmd_line actual_line
    svc_line="$(grep -Fn "  ${name}:" "$compose_file" | head -n1 | cut -d: -f1)"
    if [[ -n "$svc_line" ]]; then
      # Fix internal port (8000 -> 8501)
      port_line="$(tail -n "+${svc_line}" "$compose_file" | grep -n ':8000"' | head -n1 | cut -d: -f1)"
      if [[ -n "$port_line" ]]; then
        actual_line=$((svc_line + port_line - 1))
        sed -i "${actual_line}s|:8000\"|:8501\"|" "$compose_file"
      fi
      # Replace sleep infinity with streamlit run
      cmd_line="$(tail -n "+${svc_line}" "$compose_file" | grep -n 'command: sleep infinity' | head -n1 | cut -d: -f1)"
      if [[ -n "$cmd_line" ]]; then
        actual_line=$((svc_line + cmd_line - 1))
        local sed_safe_run_cmd; sed_safe_run_cmd="$(_sed_escape "$run_path")"
        sed -i "${actual_line}s|command: sleep infinity|command: streamlit run ${sed_safe_run_cmd} --server.port=8501 --server.address=0.0.0.0|" "$compose_file"
      fi
    fi
  fi

  # ---- 6. pyproject.toml: remove [project.scripts] ----
  if [[ -f "${project_path}/pyproject.toml" ]]; then
    if grep -Fq '[project.scripts]' "${project_path}/pyproject.toml"; then
      sed -i '/^\[project\.scripts\]/,/^\[/{/^\[project\.scripts\]/d;/^\[/!d}' "${project_path}/pyproject.toml"
    fi
  fi

  # ---- 7. tests/test_main.py ----
  local test_file="${project_path}/tests/test_main.py"
  if [[ -f "$test_file" ]] && ! grep -q 'AppTest' "$test_file" 2>/dev/null; then
    render_template "$tpl_dir/templates/tests/test_main.py" "$test_file" "TEST_PATH=${run_path}"
  fi

  # ---- 8. README.md — update Usage section for streamlit ----
  local readme="${project_path}/README.md"
  if [[ -f "$readme" ]] && ! grep -Fq 'streamlit' "$readme"; then
    local sed_safe_run; sed_safe_run="$(_sed_escape "$run_path")"

    if grep -Fq 'python main.py' "$readme"; then
      sed -i "s|python main.py|streamlit run ${sed_safe_run}|" "$readme"
    else
      # src layer already replaced 'python main.py' with the project name.
      # Locate the code block inside ## Usage and replace the command.
      local bash_line
      bash_line="$(awk '/^## Usage$/{f=1} f && /^```bash$/{print NR; exit}' "$readme")"
      if [[ -n "$bash_line" ]]; then
        local cmd_line=$((bash_line + 1))
        sed -i "${cmd_line}s|.*|streamlit run ${sed_safe_run}|" "$readme"
      fi
    fi

    # Note about URL after the ## Usage code block
    if ! grep -Fq 'localhost:8501' "$readme"; then
      local close_line
      close_line="$(awk '/^## Usage$/{f=1} f && /^```$/{print NR; exit}' "$readme")"
      if [[ -n "$close_line" ]]; then
        local note_tmp; note_tmp="$(make_temp)"
        local tpl_dir_st; tpl_dir_st="$(find_layer_templates_dir "python" "streamlit")"
        cp "$tpl_dir_st/fragments/readme-streamlit-note.md" "$note_tmp"
        sed -i "${close_line}r ${note_tmp}" "$readme"
      fi
    fi

    # Docker (Production) section: update port 8000 → 8501
    sed -i 's|docker run -p 8000:8000|docker run -p 8501:8501|' "$readme"
  fi

  # ---- 9. .gitignore — protege secrets ----
  local gitignore="${project_path}/.gitignore"
  if [[ -f "$gitignore" ]]; then
    if ! grep -Fq '.streamlit/secrets.toml' "$gitignore"; then
      printf '\n# Streamlit secrets (API keys, tokens)\n.streamlit/secrets.toml\n' >> "$gitignore"
    fi
  fi

  # ---- 10. Log final ----
  echo "  Layer:    streamlit (full showcase, port 8501)"
}
