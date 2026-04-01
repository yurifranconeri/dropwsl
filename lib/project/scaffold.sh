#!/usr/bin/env bash
# lib/project/scaffold.sh -- Scaffold devcontainer for projects.
# Requires: common.sh sourced

[[ -n "${_SCAFFOLD_SH_LOADED:-}" ]] && return 0
_SCAFFOLD_SH_LOADED=1

# Lists available languages from the templates directory.
list_available_langs() {
  local templates_dir
  templates_dir="$(find_templates_dir)"
  AVAILABLE_LANGS=()
  local d
  for d in "$templates_dir"/*/; do
    [[ -d "$d" ]] && AVAILABLE_LANGS+=("$(basename "$d")")
  done
  if [[ ${#AVAILABLE_LANGS[@]} -eq 0 ]]; then
    die_hint "No templates found in ${templates_dir}/." \
      "Incomplete repository or sync failed" \
      "Run: dropwsl --update (re-syncs from Windows);Run: .\\install.cmd again" \
      "ls ${templates_dir}/"
  fi
}

# Creates .devcontainer/ in the current directory from the language template.
scaffold_devcontainer() {
  local lang="${1:-}"
  local called_from_new="${2:-false}"
  local templates_dir
  templates_dir="$(find_templates_dir)"

  if [[ -z "$lang" ]]; then
    list_available_langs
    log "Available languages for scaffold:"
    echo
    local l
    for l in "${AVAILABLE_LANGS[@]}"; do
      echo "  $l"
    done
    echo
    echo "Usage: dropwsl scaffold <language>"
    echo "E.g.: dropwsl scaffold python"
    return 0
  fi

  local template_src="${templates_dir}/${lang}"

  if [[ ! -d "$template_src" ]]; then
    list_available_langs
    local avail_str="${AVAILABLE_LANGS[*]}"
    die_hint "Template '${lang}' not found in ${templates_dir}/." \
      "Language not supported;Typo in language name" \
      "Available templates: ${avail_str// /, };Run: dropwsl scaffold (lists all)" \
      "ls ${templates_dir}/"
  fi

  if [[ ! -d "${template_src}/.devcontainer" ]]; then
    die_hint "Template '${lang}' malformed: missing .devcontainer/." \
      "Incomplete sync;Corrupted template" \
      "Run: dropwsl --update (re-syncs from Windows);Run: .\\install.cmd again" \
      "ls ${template_src}/"
  fi

  local target_dir
  target_dir="$(pwd)"

  if [[ -d "${target_dir}/.devcontainer" ]]; then
    if [[ "$ASSUME_YES" != true ]] && [[ "$called_from_new" != true ]]; then
      warn ".devcontainer/ already exists in ${target_dir}"
      local confirm
      read -rp "Overwrite? (y/N) " confirm
      [[ "$confirm" =~ ^[yY]$ ]] || { echo "Cancelled."; return 0; }
    fi
    warn "Existing .devcontainer/ will be overwritten"
    log "Removing existing .devcontainer/ to recreate"
    rm -rf "${target_dir}/.devcontainer"
  fi

  log "Creating .devcontainer/ from template '${lang}'"
  cp -r "${template_src}/.devcontainer" "${target_dir}/.devcontainer"

  local gitignore_copied=false
  if [[ -f "${template_src}/.gitignore" ]] && [[ ! -f "${target_dir}/.gitignore" ]]; then
    cp "${template_src}/.gitignore" "${target_dir}/.gitignore"
    gitignore_copied=true
  fi

  # Copy starter files (no-clobber)
  local starter_files_copied=()
  local fname f
  for f in "${template_src}"/*; do
    fname="$(basename "$f")"

    if [[ -d "$f" ]]; then
      [[ "$fname" == ".devcontainer" ]] && continue
      if [[ ! -d "${target_dir}/${fname}" ]]; then
        cp -r "$f" "${target_dir}/${fname}"
        starter_files_copied+=("${fname}/")
      fi
    else
      if [[ ! -f "${target_dir}/${fname}" ]]; then
        cp "$f" "${target_dir}/${fname}"
        starter_files_copied+=("$fname")
      fi
    fi
  done

  # Copy dotfiles from template
  for f in "${template_src}"/.[!.]*; do
    [[ ! -e "$f" ]] && continue
    [[ -d "$f" ]] && continue
    fname="$(basename "$f")"
    [[ "$fname" == ".gitignore" ]] && continue
    if [[ ! -f "${target_dir}/${fname}" ]]; then
      cp "$f" "${target_dir}/${fname}"
      starter_files_copied+=("$fname")
    fi
  done

  echo
  echo "Files created:"
  find "${target_dir}/.devcontainer" -type f | while read -r entry; do
    echo "  ${entry#${target_dir}/}"
  done
  [[ "$gitignore_copied" == true ]] && echo "  .gitignore"
  local sf
  for sf in "${starter_files_copied[@]}"; do
    echo "  $sf"
  done

  if [[ "$called_from_new" != true ]]; then
    echo
    echo "Next steps:"
    echo "  1. Open the folder in VS Code: code ."
    echo "  2. VS Code will suggest 'Reopen in Container' -- accept it"
    echo "  3. Or use Ctrl+Shift+P -> 'Dev Containers: Reopen in Container'"
  fi
}
