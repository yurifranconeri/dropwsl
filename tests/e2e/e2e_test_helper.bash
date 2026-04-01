#!/usr/bin/env bash
# tests/e2e/e2e_test_helper.bash — Helpers for E2E tests (real Docker runtime)
# Requires: Docker daemon running, free ports (dynamic allocation)
#
# IMPORTANT: Docker tests use setup_file/teardown_file for build+start
# ONCE per file. Individual tests validate the already running stack.
# This helper MUST be loaded in both setup_file() and setup() —
# bats runs setup_file and @test in different subshells.

BATS_TEST_DIR="${BATS_TEST_DIR:-$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)}"
REPO_ROOT="${REPO_ROOT:-$(cd "$BATS_TEST_DIR" && while [[ ! -f dropwsl.sh ]] && [[ "$PWD" != "/" ]]; do cd ..; done; pwd)}"

# Source project modules (needed for create_test_project)
export SCRIPT_DIR="$REPO_ROOT"
export LOG_FILE="/dev/null"
export QUIET=true
export ASSUME_YES=true

unset _COMMON_SH_LOADED
source "${REPO_ROOT}/lib/common.sh"

# Colorless overrides — ALL log functions (common.sh defines with ANSI codes)
log()  { echo "==> $*"; }
warn() { echo "[WARN] $*" >&2; }
die()  { echo "[ERROR] $*" >&2; exit 1; }
die_hint() {
  local msg="$1"
  echo "[ERROR] $msg" >&2
  exit 1
}

unset _LAYERS_SH_LOADED _SCAFFOLD_SH_LOADED _NEW_SH_LOADED _WORKSPACE_SH_LOADED
source "${REPO_ROOT}/lib/project/layers.sh"
source "${REPO_ROOT}/lib/project/scaffold.sh"
source "${REPO_ROOT}/lib/project/new.sh"
source "${REPO_ROOT}/lib/project/workspace.sh"

# Load config.yaml to populate DEFAULT_LAYERS (e.g.: uv, gitleaks)
load_config "${REPO_ROOT}/config.yaml"

# Prevent new_project() from opening VS Code during tests
code() { :; }
export -f code

# ---- Signal handling (Ctrl+C mata docker children) ----
_docker_test_cleanup_on_signal() {
  trap - INT TERM
  pkill -P $$ -f 'docker' 2>/dev/null || true
  exit 130
}
trap '_docker_test_cleanup_on_signal' INT TERM

# ---- Progress output (via TAP pipe for correct ordering) ----

# Writes progress via FD 3 (TAP pipe → formatter).
# FD 3 is priority because the formatter processes lines sequentially:
# upon receiving our line, the "unknown" handler calls flush() — ensuring
# pending results (ok/not ok, suite) are printed BEFORE our msg.
# Fallback /dev/tty for contexts without FD 3 (e.g.: outside bats).
progress() {
  local msg
  msg="$(printf "    \033[0;90m%s\033[0m" "$*")"
  if { true >&3; } 2>/dev/null; then
    printf "%s\n" "$msg" >&3
  elif [[ -w /dev/tty ]]; then
    printf "\r\033[2K%s\n" "$msg" >/dev/tty
  fi
}

# Shows progressive dots every second
_progress_dot() {
  if { true >&3; } 2>/dev/null; then
    printf "\033[0;90m.\033[0m" >&3
  elif [[ -w /dev/tty ]]; then
    printf "\033[0;90m.\033[0m" >/dev/tty
  fi
}

_progress_newline() {
  if { true >&3; } 2>/dev/null; then
    printf "\n" >&3
  elif [[ -w /dev/tty ]]; then
    printf "\n" >/dev/tty
  fi
}

# Executes command with progressive dots feedback (1 dot/second).
# First arg is the progress message (displayed inline before dots).
# Dots go directly to /dev/tty (bypass bats TAP pipe buffering).
_run_with_dots() {
  local msg="$1"; shift

  # Emit message + dots directly to terminal (without bats buffering)
  if [[ -w /dev/tty ]]; then
    printf "    \033[0;90m%s\033[0m" "$msg" >/dev/tty
    local dot_pid
    ( while true; do printf "\033[0;90m.\033[0m" >/dev/tty; sleep 1; done ) &
    dot_pid=$!
    trap "kill $dot_pid 2>/dev/null || true" RETURN
    "$@"
    local rc=$?
    kill $dot_pid 2>/dev/null || true
    wait $dot_pid 2>/dev/null || true
    printf "\n" >/dev/tty
    return $rc
  else
    # No terminal — run without dots (CI, pipe)
    "$@"
  fi
}

# ---- Pre-checks ----

skip_if_no_docker() {
  if ! docker info >/dev/null 2>&1; then
    skip "Docker not available -- docker info failed"
  fi
}

# ---- Project creation ----

create_test_project() {
  local lang="${1:-python}"
  local layers="${2:-}"

  local name="dt-$$-${RANDOM}"
  export PROJECTS_DIR="${TEST_TEMP}/projects"
  mkdir -p "$PROJECTS_DIR"

  export COMPOSE_PROJECT_NAME="${name}"

  local layers_desc="${layers:-none}"
  progress "Creating project ${name} [${lang}, layers: ${layers_desc}]..."
  new_project "$name" "$lang" "$layers" "" >&2

  echo "${PROJECTS_DIR}/${name}"
}

# ---- Dynamic ports ----

find_free_port() {
  python3 -c "import socket; s=socket.socket(); s.bind(('',0)); print(s.getsockname()[1]); s.close()"
}

rewrite_compose_port() {
  local compose_file="$1"
  local internal_port="$2"

  if [[ ! -f "$compose_file" ]]; then
    echo "ERROR: compose file not found: $compose_file" >&2
    return 1
  fi

  local external_port
  external_port="$(find_free_port)"

  # Tries quoted: "8000:8000"
  sed -i "s|\"${internal_port}:${internal_port}\"|\"${external_port}:${internal_port}\"|g" "$compose_file"

  # If it didn't match, try unquoted
  if ! grep -q "${external_port}:${internal_port}" "$compose_file"; then
    sed -i "s|${internal_port}:${internal_port}|${external_port}:${internal_port}|g" "$compose_file"
  fi

  if ! grep -q "${external_port}:${internal_port}" "$compose_file"; then
    echo "WARN: port rewrite failed for ${internal_port} in $compose_file" >&2
    grep -n "port\|${internal_port}" "$compose_file" >&2 || true
    echo "${internal_port}"
    return 0
  fi

  echo "$external_port"
}

# ---- Docker operations (compose) ----

docker_build() {
  local project_dir="$1"
  local profile="${2:-prod}"
  local max_retries=2 attempt=1
  while true; do
    if _run_with_dots "Building compose images..." docker compose -f "${project_dir}/compose.yaml" --profile "$profile" build 2>&1; then
      return 0
    fi
    if (( attempt >= max_retries )); then
      echo "ERROR: docker compose build failed after $max_retries attempts" >&2
      return 1
    fi
    echo "WARN: build failed (attempt $attempt/$max_retries) -- retrying in 10s..." >&2
    sleep 10
    (( attempt++ ))
  done
}

docker_up() {
  local project_dir="$1"
  local profile="${2:-prod}"
  _run_with_dots "Starting services (profile: ${profile})..." docker compose -f "${project_dir}/compose.yaml" --profile "$profile" up -d --wait --wait-timeout 120 2>&1
}

docker_up_infra() {
  local project_dir="$1"
  _run_with_dots "Starting infra services..." docker compose -f "${project_dir}/compose.yaml" up -d --wait --wait-timeout 90 2>&1
}

run_in_container() {
  local project_dir="$1"; shift
  docker compose -f "${project_dir}/compose.yaml" --profile prod exec -T app "$@" 2>&1
}

# ---- Docker operations (standalone — no compose) ----

docker_build_image() {
  local project_dir="$1"
  local tag="$2"
  local max_retries=2 attempt=1
  while true; do
    if _run_with_dots "Building image ${tag}..." docker build -t "$tag" "$project_dir" 2>&1; then
      return 0
    fi
    if (( attempt >= max_retries )); then
      echo "ERROR: docker build failed after $max_retries attempts" >&2
      return 1
    fi
    echo "WARN: build failed (attempt $attempt/$max_retries) -- retrying in 10s..." >&2
    sleep 10
    (( attempt++ ))
  done
}

docker_run_oneshot() {
  local tag="$1"; shift
  docker run --rm "$tag" "$@" 2>&1
}

docker_run_detached() {
  local tag="$1"
  local host_port="$2"
  local container_port="$3"
  # Without --rm: teardown does stop + rm explicitly
  docker run -d -p "${host_port}:${container_port}" "$tag"
}

docker_stop_container() {
  local container_id="$1"
  [[ -z "$container_id" ]] && return 0
  docker stop "$container_id" --time 5 2>/dev/null || true
  docker rm -f "$container_id" 2>/dev/null || true
}

docker_remove_image() {
  local tag="$1"
  docker rmi -f "$tag" 2>/dev/null || true
}

# ---- Health checks ----

wait_for_http() {
  local url="$1"
  local timeout="${2:-30}"
  progress "Waiting for ${url} (timeout: ${timeout}s)..."
  local i=0
  while ! curl -sf --max-time 2 "$url" >/dev/null 2>&1; do
    ((i++))
    if [[ $i -ge $timeout ]]; then
      _progress_newline
      echo "=== wait_for_http TIMEOUT ($url, ${timeout}s) ===" >&2
      echo "curl -v output:" >&2
      curl -v "$url" 2>&1 | head -20 >&2 || true
      echo "docker ps:" >&2
      docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" >&2 || true
      return 1
    fi
    _progress_dot
    sleep 1
  done
  _progress_newline
  return 0
}

# Dump compose logs for diagnostic when setup_file fails
dump_compose_logs() {
  local project_dir="$1"
  [[ -f "${project_dir}/compose.yaml" ]] || return 0
  echo "=== docker compose logs (app) ===" >&2
  docker compose -f "${project_dir}/compose.yaml" --profile prod logs app 2>&1 | tail -30 >&2 || true
  echo "=== docker compose ps ===" >&2
  docker compose -f "${project_dir}/compose.yaml" --profile prod ps >&2 || true
}

# Dump standalone container logs
dump_container_logs() {
  local container_id="$1"
  [[ -z "$container_id" ]] && return 0
  echo "=== docker logs ${container_id} ===" >&2
  docker logs "$container_id" 2>&1 | tail -30 >&2 || true
}

# ---- Cleanup ----

docker_cleanup() {
  local project_dir="$1"
  local compose_file="${project_dir}/compose.yaml"

  if [[ -f "$compose_file" ]]; then
    docker compose -f "$compose_file" --profile prod down -v --remove-orphans --timeout 10 2>/dev/null || true
  fi

  local project_name="${COMPOSE_PROJECT_NAME:-}"
  if [[ -n "$project_name" ]]; then
    docker images --filter "label=com.docker.compose.project=${project_name}" -q 2>/dev/null \
      | xargs -r docker rmi -f 2>/dev/null || true
  fi
}
