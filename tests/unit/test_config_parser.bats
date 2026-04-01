#!/usr/bin/env bats
# tests/unit/test_config_parser.bats — Tests for load_config()

setup() {
  load '../helpers/test_helper'
  _common_setup
  FIXTURES="${REPO_ROOT}/tests/fixtures"
}

teardown() {
  _common_teardown
}

# Reset globals before each test
reset_config_globals() {
  SUPPORTED_DISTROS=(ubuntu debian)
  MIN_UBUNTU="22.04"
  MIN_DEBIAN="12"
  REPO_URL=""
  INSTALL_DIR="${HOME}/.local/share/dropwsl"
  PROJECTS_DIR="${HOME}/projects"
  KUBECTL_VERSION="1.34"
  KIND_VERSION="v0.27.0"
  HELM_VERSION="v3.17.3"
  ENABLED_CORE=()
  DOCKER_MTU=1400
  DOCKER_LOG_MAX_SIZE="10m"
  DOCKER_LOG_MAX_FILE=3
  GITLEAKS_VERSION=""
  MCP_FETCH_VERSION=""
  MCP_GIT_VERSION=""
  MCP_GITHUB_VERSION=""
  VSCODE_EXTENSIONS=(ms-vscode-remote.remote-wsl ms-vscode-remote.remote-containers ms-azuretools.vscode-docker)
  declare -gA GIT_DEFAULTS=([init.defaultBranch]="main" [core.autocrlf]="input")
  DEFAULT_LAYERS=()
}

@test "config_parser: full config populates all variables" {
  reset_config_globals
  load_config "${FIXTURES}/config_all_enabled.yaml"
  assert [ "${#SUPPORTED_DISTROS[@]}" -eq 2 ]
  assert [ "${MIN_UBUNTU}" = "22.04" ]
  assert [ "${MIN_DEBIAN}" = "12" ]
}

@test "config_parser: distros parsed correctly" {
  reset_config_globals
  load_config "${FIXTURES}/config_all_enabled.yaml"
  assert [ "${SUPPORTED_DISTROS[0]}" = "ubuntu" ]
  assert [ "${SUPPORTED_DISTROS[1]}" = "debian" ]
}

@test "config_parser: min versions" {
  reset_config_globals
  load_config "${FIXTURES}/config_all_enabled.yaml"
  assert [ "${MIN_UBUNTU}" = "22.04" ]
  assert [ "${MIN_DEBIAN}" = "12" ]
}

@test "config_parser: tool versions" {
  reset_config_globals
  load_config "${FIXTURES}/config_all_enabled.yaml"
  assert [ "${KUBECTL_VERSION}" = "1.34" ]
  assert [ "${KIND_VERSION}" = "v0.27.0" ]
  assert [ "${HELM_VERSION}" = "v3.17.3" ]
}

@test "config_parser: ENABLED_CORE populated" {
  reset_config_globals
  load_config "${FIXTURES}/config_all_enabled.yaml"
  local core_str="${ENABLED_CORE[*]}"
  [[ "$core_str" == *"docker"* ]]
  [[ "$core_str" == *"kubectl"* ]]
  [[ "$core_str" == *"kind"* ]]
  [[ "$core_str" == *"helm"* ]]
}

@test "config_parser: disabled tool not in ENABLED_CORE" {
  reset_config_globals
  load_config "${FIXTURES}/config_minimal.yaml"
  local core_str="${ENABLED_CORE[*]:-}"
  [[ "$core_str" != *"docker"* ]]
}

@test "config_parser: VS Code extensions" {
  reset_config_globals
  load_config "${FIXTURES}/config_all_enabled.yaml"
  assert [ "${#VSCODE_EXTENSIONS[@]}" -ge 3 ]
  local ext_str="${VSCODE_EXTENSIONS[*]}"
  [[ "$ext_str" == *"ms-vscode-remote.remote-wsl"* ]]
}

@test "config_parser: git defaults" {
  reset_config_globals
  load_config "${FIXTURES}/config_all_enabled.yaml"
  assert [ "${GIT_DEFAULTS[init.defaultBranch]}" = "main" ]
  assert [ "${GIT_DEFAULTS[core.autocrlf]}" = "input" ]
  assert [ "${GIT_DEFAULTS[rebase.autoStash]}" = "true" ]
}

@test "config_parser: MCP server versions" {
  reset_config_globals
  load_config "${FIXTURES}/config_all_enabled.yaml"
  assert [ "$MCP_FETCH_VERSION" = "2025.1.14" ]
  assert [ "$MCP_GIT_VERSION" = "2025.1.14" ]
  assert [ "$MCP_GITHUB_VERSION" = "2025.6.18" ]
}

@test "config_parser: gitleaks version" {
  reset_config_globals
  load_config "${FIXTURES}/config_all_enabled.yaml"
  assert [ "$GITLEAKS_VERSION" = "v8.21.2" ]
}

@test "config_parser: default layers" {
  reset_config_globals
  load_config "${FIXTURES}/config_all_enabled.yaml"
  local layers_str="${DEFAULT_LAYERS[*]}"
  [[ "$layers_str" == *"src"* ]]
  [[ "$layers_str" == *"mypy"* ]]
}

@test "config_parser: real config.yaml has uv in defaults" {
  reset_config_globals
  load_config "${REPO_ROOT}/config.yaml"
  local layers_str="${DEFAULT_LAYERS[*]}"
  [[ "$layers_str" == *"uv"* ]]
  [[ "$layers_str" == *"gitleaks"* ]]
  [[ "$layers_str" == *"trivy"* ]]
}

@test "config_parser: nonexistent file does not change variables" {
  reset_config_globals
  local old_ubuntu="$MIN_UBUNTU"
  load_config "/dev/null/nonexistent"
  assert [ "$MIN_UBUNTU" = "$old_ubuntu" ]
}

@test "config_parser: empty file does not change variables" {
  reset_config_globals
  local empty="${TEST_TEMP}/empty.yaml"
  touch "$empty"
  local old_ubuntu="$MIN_UBUNTU"
  load_config "$empty"
  assert [ "$MIN_UBUNTU" = "$old_ubuntu" ]
}

@test "config_parser: CRLF in config is handled" {
  reset_config_globals
  local crlf_config="${TEST_TEMP}/crlf.yaml"
  sed 's/$/\r/' "${FIXTURES}/config_all_enabled.yaml" > "$crlf_config"
  load_config "$crlf_config"
  # Values must not have \r
  [[ "${MIN_UBUNTU}" != *$'\r'* ]]
  [[ "${KUBECTL_VERSION}" != *$'\r'* ]]
}

@test "config_parser: git defaults with inline comments strip trailing quotes" {
  reset_config_globals
  load_config "${FIXTURES}/config_all_enabled.yaml"
  # Values with inline comments (e.g. "zdiff3"   # comment) must not have trailing quotes
  assert [ "${GIT_DEFAULTS[merge.conflictstyle]}" = "zdiff3" ]
  assert [ "${GIT_DEFAULTS[rerere.enabled]}" = "true" ]
  # Verify no trailing whitespace or quote residue
  [[ "${GIT_DEFAULTS[merge.conflictstyle]}" != *'"'* ]]
  [[ "${GIT_DEFAULTS[rerere.enabled]}" != *'"'* ]]
}

@test "config_parser: projects.dir with ~ is expanded" {
  reset_config_globals
  load_config "${FIXTURES}/config_all_enabled.yaml"
  [[ "$PROJECTS_DIR" != *"~"* ]]
  [[ "$PROJECTS_DIR" == "${HOME}"* ]]
}

@test "config_parser: values with quotes are cleaned" {
  reset_config_globals
  load_config "${FIXTURES}/config_all_enabled.yaml"
  # REPO_URL and MIN_UBUNTU have quotes in YAML — must be removed
  [[ "${MIN_UBUNTU}" != *'"'* ]]
}

@test "config_parser: config without tools" {
  reset_config_globals
  load_config "${FIXTURES}/config_empty_tools.yaml"
  # Must not crash, ENABLED_CORE empty or uses defaults
  assert [ "${#SUPPORTED_DISTROS[@]}" -ge 1 ]
}

# ---- Bug #108: 2-space indent YAML should still parse ----

@test "config_parser: 2-space indent YAML parses correctly" {
  reset_config_globals
  load_config "${FIXTURES}/config_2space_indent.yaml"
  # docker should be enabled even with 2-space indent
  local core_str="${ENABLED_CORE[*]:-}"
  [[ "$core_str" == *"docker"* ]]
  # Version should be parsed
  assert [ "${KUBECTL_VERSION}" = "1.34" ]
  # Min version should be parsed
  assert [ "${MIN_UBUNTU}" = "24.04" ]
}

# ---- Bug #104: homonymous key across sections ----

@test "config_parser: homonymous key does not cross-contaminate" {
  reset_config_globals
  load_config "${FIXTURES}/config_homonymous_key.yaml"
  # kubectl version should be "1.34" — not "should-not-leak" from top-level
  assert [ "${KUBECTL_VERSION}" = "1.34" ]
  # Distro should be parsed correctly
  assert [ "${SUPPORTED_DISTROS[0]}" = "ubuntu" ]
}

# ---- Bug #105: trap _prev_exit_trap with escaped single quotes ----

@test "config_parser: sourcing common.sh preserves existing EXIT trap (trap chaining)" {
  # Verify that common.sh's additive trap doesn't destroy a pre-existing EXIT handler.
  # Bug #105: if the sed parsing of trap -p output breaks, the old trap is lost.
  run bash -c "
    trap 'echo OLD_TRAP_FIRED' EXIT
    unset _COMMON_SH_LOADED
    source '${REPO_ROOT}/lib/common.sh'
    echo SOURCED_OK
  "
  # common.sh must source without crash
  assert_output --partial "SOURCED_OK"
  # The old EXIT trap must still fire (trap chaining preserved)
  assert_output --partial "OLD_TRAP_FIRED"
}

@test "config_parser: docker daemon config (mtu, log_max_size, log_max_file)" {
  reset_config_globals
  load_config "${FIXTURES}/config_all_enabled.yaml"
  assert [ "${DOCKER_MTU}" = "1400" ]
  assert [ "${DOCKER_LOG_MAX_SIZE}" = "10m" ]
  assert [ "${DOCKER_LOG_MAX_FILE}" = "3" ]
}

@test "config_parser: docker daemon config custom values" {
  reset_config_globals
  local custom="${TEST_TEMP}/docker_custom.yaml"
  cat > "$custom" <<'EOF'
core:
  docker:
    enabled: true
    mtu: 1200
    log_max_size: "50m"
    log_max_file: 5
EOF
  load_config "$custom"
  assert [ "${DOCKER_MTU}" = "1200" ]
  assert [ "${DOCKER_LOG_MAX_SIZE}" = "50m" ]
  assert [ "${DOCKER_LOG_MAX_FILE}" = "5" ]
}

@test "config_parser: docker daemon config uses defaults when not in config" {
  reset_config_globals
  local minimal="${TEST_TEMP}/docker_minimal.yaml"
  cat > "$minimal" <<'EOF'
core:
  docker:
    enabled: true
EOF
  load_config "$minimal"
  assert [ "${DOCKER_MTU}" = "1400" ]
  assert [ "${DOCKER_LOG_MAX_SIZE}" = "10m" ]
  assert [ "${DOCKER_LOG_MAX_FILE}" = "3" ]
}

# ---- get_distro_info (DRY helper for core installers) ----

@test "get_distro_info: populates DISTRO_ID and DISTRO_CODENAME" {
  run bash -c "
    unset _COMMON_SH_LOADED
    source '${REPO_ROOT}/lib/common.sh'
    get_distro_info
    echo \"ID=\${DISTRO_ID}\"
    echo \"CODENAME=\${DISTRO_CODENAME}\"
  "
  assert_success
  assert_output --partial "ID="
  assert_output --partial "CODENAME="
}

@test "get_distro_info: values match /etc/os-release" {
  local expected_id expected_codename
  expected_id="$(sed -n 's/^ID=//p' /etc/os-release | tr -d '"')"
  expected_codename="$(sed -n 's/^VERSION_CODENAME=//p' /etc/os-release | tr -d '"')"
  run bash -c "
    unset _COMMON_SH_LOADED
    source '${REPO_ROOT}/lib/common.sh'
    get_distro_info
    echo \"\${DISTRO_ID}|\${DISTRO_CODENAME}\"
  "
  assert_success
  assert_output "${expected_id}|${expected_codename}"
}
