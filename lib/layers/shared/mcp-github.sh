#!/usr/bin/env bash
# lib/layers/shared/mcp-github.sh — Layer: MCP GitHub server
# Configures .vscode/mcp.json to consume the GitHub MCP server in Copilot Agent Mode.
# Cross-language: works with any template.

[[ -n "${_MCP_GITHUB_SH_LOADED:-}" ]] && return 0
_MCP_GITHUB_SH_LOADED=1

_LAYER_PHASE="devtools"
_LAYER_CONFLICTS=""
_LAYER_REQUIRES=""

apply_layer_mcp_github() {
  local project_path="$1"
  local mcp_github_ver="${MCP_GITHUB_VERSION:-2025.6.18}"

  log "Applying layer: mcp-github (GitHub MCP server)"

  inject_mcp_server "$project_path" "github" "      \"type\": \"stdio\",
      \"command\": \"npx\",
      \"args\": [\"-y\", \"@modelcontextprotocol/server-github@${mcp_github_ver}\"],
      \"env\": {
        \"GITHUB_PERSONAL_ACCESS_TOKEN\": \"\${input:github-pat}\"
      }"

  # Inject input for the token
  local mcp_file="${project_path}/.vscode/mcp.json"
  if [[ -f "$mcp_file" ]] && ! grep -q '"github-pat"' "$mcp_file"; then

    local tpl_dir_mcp; tpl_dir_mcp="$(find_layer_templates_dir "shared" "mcp-github")"

    # Detect inputs state: populated, empty, or absent
    # Find the inputs line and extract just the [ ... ] content on that line
    local inputs_state="absent"
    if grep -q '"inputs"' "$mcp_file"; then
      local inputs_line
      inputs_line="$(grep '"inputs"' "$mcp_file" | head -n1)"
      if echo "$inputs_line" | grep -q '\[\]'; then
        inputs_state="empty"
      else
        inputs_state="populated"
      fi
    fi

    if [[ "$inputs_state" == "populated" ]]; then
      # Populated inputs array — merge entry after [ (fragment trailing comma = separator)
      local inject_tmp; inject_tmp="$(make_temp)"
      cp "$tpl_dir_mcp/fragments/mcp-input-github-pat.json" "$inject_tmp"
      local tmp; tmp="$(make_temp)"
      sed '/"inputs" *: *\[/r '"$inject_tmp" "$mcp_file" > "$tmp"
      mv "$tmp" "$mcp_file"
    elif [[ "$inputs_state" == "empty" ]]; then
      # Empty inputs array (e.g. "inputs": []) — replace line with populated block
      local replace_tmp; replace_tmp="$(make_temp)"
      cp "$tpl_dir_mcp/fragments/mcp-inputs-block.json" "$replace_tmp"
      local inputs_start
      inputs_start="$(grep -Fn '"inputs"' "$mcp_file" | head -n1 | cut -d: -f1)"
      if [[ -n "$inputs_start" ]]; then
        local tmp; tmp="$(make_temp)"
        {
          head -n "$((inputs_start - 1))" "$mcp_file"
          cat "$replace_tmp"
          tail -n "+$((inputs_start + 1))" "$mcp_file"
        } > "$tmp"
        mv "$tmp" "$mcp_file"
      fi
    else
      # No inputs at all — prepend inputs block before servers
      local tmp; tmp="$(make_temp)"
      {
        head -n 1 "$mcp_file"
        cat "$tpl_dir_mcp/fragments/mcp-inputs-block.json"
        tail -n +2 "$mcp_file"
      } > "$tmp"
      mv "$tmp" "$mcp_file"
    fi
  fi

  echo "  Layer:    mcp-github (repos, issues, PRs via Copilot Agent Mode)"
}
