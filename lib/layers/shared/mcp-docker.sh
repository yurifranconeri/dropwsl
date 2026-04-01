#!/usr/bin/env bash
# lib/layers/shared/mcp-docker.sh — Layer: MCP Docker server
# Configures .vscode/mcp.json to consume the Docker MCP server in Copilot Agent Mode.
# Cross-language: works with any template.

[[ -n "${_MCP_DOCKER_SH_LOADED:-}" ]] && return 0
_MCP_DOCKER_SH_LOADED=1

_LAYER_PHASE="devtools"
_LAYER_CONFLICTS=""
_LAYER_REQUIRES=""

apply_layer_mcp_docker() {
  local project_path="$1"

  log "Applying layer: mcp-docker (Docker MCP server)"

  # Uses Docker CLI directly (socket already mounted in Dev Container)
  # NOTE: mcp/docker without tag -> uses :latest. Pin when stable version exists.
  inject_mcp_server "$project_path" "docker" "      \"type\": \"stdio\",
      \"command\": \"docker\",
      \"args\": [\"run\", \"--rm\", \"-i\", \"--mount\", \"type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock\", \"mcp/docker\"]"

  echo "  Layer:    mcp-docker (containers, images, compose via Copilot Agent Mode)"
}
