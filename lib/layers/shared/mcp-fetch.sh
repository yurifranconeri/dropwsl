#!/usr/bin/env bash
# lib/layers/shared/mcp-fetch.sh — Layer: MCP Fetch server (Anthropic reference)
# Configures .vscode/mcp.json to consume the Fetch MCP server in Copilot Agent Mode.
# Cross-language: works with any template.

[[ -n "${_MCP_FETCH_SH_LOADED:-}" ]] && return 0
_MCP_FETCH_SH_LOADED=1

_LAYER_PHASE="devtools"
_LAYER_CONFLICTS=""
_LAYER_REQUIRES=""

apply_layer_mcp_fetch() {
  local project_path="$1"
  local mcp_fetch_ver="${MCP_FETCH_VERSION:-2025.1.14}"

  log "Applying layer: mcp-fetch (HTTP fetch MCP server)"

  inject_mcp_server "$project_path" "fetch" "      \"type\": \"stdio\",
      \"command\": \"npx\",
      \"args\": [\"-y\", \"@modelcontextprotocol/server-fetch@${mcp_fetch_ver}\"]"

  echo "  Layer:    mcp-fetch (HTTP requests to test/explore APIs via Copilot Agent Mode)"
}
