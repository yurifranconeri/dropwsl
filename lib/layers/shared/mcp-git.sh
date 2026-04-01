#!/usr/bin/env bash
# lib/layers/shared/mcp-git.sh — Layer: MCP Git server (Anthropic reference)
# Configures .vscode/mcp.json to consume the Git MCP server in Copilot Agent Mode.
# Cross-language: works with any template.

[[ -n "${_MCP_GIT_SH_LOADED:-}" ]] && return 0
_MCP_GIT_SH_LOADED=1

_LAYER_PHASE="devtools"
_LAYER_CONFLICTS=""
_LAYER_REQUIRES=""

apply_layer_mcp_git() {
  local project_path="$1"
  local mcp_git_ver="${MCP_GIT_VERSION:-2025.1.14}"

  log "Applying layer: mcp-git (Git MCP server)"

  inject_mcp_server "$project_path" "git" "      \"type\": \"stdio\",
      \"command\": \"npx\",
      \"args\": [\"-y\", \"@modelcontextprotocol/server-git@${mcp_git_ver}\"]"

  echo "  Layer:    mcp-git (commits, branches, diffs, blame via Copilot Agent Mode)"
}
