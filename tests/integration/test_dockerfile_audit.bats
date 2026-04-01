#!/usr/bin/env bats
# tests/integration/test_dockerfile_audit.bats — Validates that all layer combinations
# generate parseable Dockerfiles (no orphan instructions, syntax errors, etc.)
#
# Layers that modify the Dockerfile: src, fastapi, streamlit, uv
# This test generates projects with all relevant combinations and validates
# that the resulting Dockerfile is syntactically valid.

setup() {
  load '../helpers/layer_test_helper'
  _common_setup
  activate_mocks
  export PROJECTS_DIR="${TEST_TEMP}/projects"
  mkdir -p "$PROJECTS_DIR"
  export NO_DEFAULTS=true
  export DEFAULT_LAYERS=()
  export ASSUME_YES=true
  code() { :; }
  export -f code
  git() { command git "$@"; }
  export -f git
}

teardown() {
  _common_teardown
}

# Validates that the Dockerfile has no orphan lines — every instruction starts with
# a known Docker keyword, comment, empty line, or continuation (space after \)
_assert_dockerfile_valid() {
  local dockerfile="$1"
  assert [ -f "$dockerfile" ]

  # Valid Docker keywords (case-insensitive in Docker, but templates use UPPER)
  local -a valid_keywords=(
    FROM RUN CMD COPY ADD EXPOSE ENV ARG LABEL WORKDIR USER
    ENTRYPOINT VOLUME ONBUILD STOPSIGNAL HEALTHCHECK SHELL
  )
  local keywords_pattern
  keywords_pattern="$(printf '%s|' "${valid_keywords[@]}")"
  keywords_pattern="^(${keywords_pattern%|})\\b"

  local line_num=0
  local prev_continuation=false
  local errors=()

  while IFS= read -r line || [[ -n "$line" ]]; do
    ((line_num++)) || true

    # Empty line — breaks continuation (Docker requires contiguous \n)
    [[ -z "${line// /}" ]] && prev_continuation=false && continue
    # Comment — does NOT reset prev_continuation.
    # Docker allows # comments inside multi-line RUN blocks with \.
    # If we're in continuation, the comment doesn't interrupt it.
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    # Continuation of previous line (indented, multi-line command after \)
    if $prev_continuation; then
      # Check if this line also continues
      if [[ "$line" =~ \\[[:space:]]*$ ]]; then
        prev_continuation=true
      else
        prev_continuation=false
      fi
      continue
    fi
    # Valid Docker instruction
    local trimmed="${line#"${line%%[![:space:]]*}"}"
    if echo "$trimmed" | grep -qEi "$keywords_pattern"; then
      if [[ "$line" =~ \\[[:space:]]*$ ]]; then
        prev_continuation=true
      else
        prev_continuation=false
      fi
      continue
    fi
    # If we got here, it's a suspicious line
    errors+=("L${line_num}: ${line}")
  done < "$dockerfile"

  if [[ ${#errors[@]} -gt 0 ]]; then
    echo "Invalid Dockerfile: ${dockerfile}" >&2
    printf "  %s\n" "${errors[@]}" >&2
    return 1
  fi
}

# Helper: generates project and validates both Dockerfiles
_test_combo() {
  local name="$1"
  local layers="$2"

  new_project "$name" "python" "$layers" "" >&2 < /dev/null
  local project="${PROJECTS_DIR}/${name}"

  # Validate production Dockerfile
  if [[ -f "${project}/Dockerfile" ]]; then
    _assert_dockerfile_valid "${project}/Dockerfile"
  fi

  # Validate devcontainer Dockerfile
  if [[ -f "${project}/.devcontainer/Dockerfile" ]]; then
    _assert_dockerfile_valid "${project}/.devcontainer/Dockerfile"
  fi
}

# ---- Base (without layers) ----

@test "dockerfile audit: base python (without layers)" {
  _test_combo "audit-base" ""
}

# ---- Single layers que modificam Dockerfile ----

@test "dockerfile audit: src" {
  _test_combo "audit-src" "src"
}

@test "dockerfile audit: fastapi" {
  _test_combo "audit-fastapi" "fastapi"
}

@test "dockerfile audit: streamlit" {
  _test_combo "audit-streamlit" "streamlit"
}

@test "dockerfile audit: uv" {
  _test_combo "audit-uv" "uv"
}

# ---- Combos de 2 layers ----

@test "dockerfile audit: src + fastapi" {
  _test_combo "audit-src-fastapi" "src,fastapi"
}

@test "dockerfile audit: src + streamlit" {
  _test_combo "audit-src-streamlit" "src,streamlit"
}

@test "dockerfile audit: src + uv" {
  _test_combo "audit-src-uv" "src,uv"
}

@test "dockerfile audit: fastapi + uv" {
  _test_combo "audit-fastapi-uv" "fastapi,uv"
}

# ---- Combos de 3 layers ----

@test "dockerfile audit: src + fastapi + uv" {
  _test_combo "audit-src-fastapi-uv" "src,fastapi,uv"
}

@test "dockerfile audit: src + fastapi + mypy" {
  _test_combo "audit-src-fastapi-mypy" "src,fastapi,mypy"
}

@test "dockerfile audit: src + streamlit + mypy" {
  _test_combo "audit-src-streamlit-mypy" "src,streamlit,mypy"
}

# ---- Full stacks (combos realistas) ----

@test "dockerfile audit: src + fastapi + compose + postgres" {
  _test_combo "audit-api-pg" "src,fastapi,compose,postgres"
}

@test "dockerfile audit: src + fastapi + compose + postgres + redis" {
  _test_combo "audit-full-api" "src,fastapi,compose,postgres,redis"
}

@test "dockerfile audit: src + fastapi + uv + compose + postgres + redis" {
  _test_combo "audit-full-api-uv" "src,fastapi,uv,compose,postgres,redis"
}

@test "dockerfile audit: src + streamlit + compose + postgres" {
  _test_combo "audit-streamlit-pg" "src,streamlit,compose,postgres"
}

@test "dockerfile audit: src + fastapi + compose + postgres + redis + locust" {
  _test_combo "audit-full-locust" "src,fastapi,compose,postgres,redis,locust"
}

@test "dockerfile audit: src + fastapi + compose + postgres + testcontainers" {
  _test_combo "audit-full-tc" "src,fastapi,compose,postgres,testcontainers"
}
