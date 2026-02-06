#!/usr/bin/env bash
# Date: 2026-02-06

github_sync_discover_projects2() {
  local search_root="${1:-.}"
  local json_output="$2"
  local github_user="${GITHUB_USER:-$GITHUB_TEST_ORG}"
  local debug="${DEBUG:-false}"
  
  # Global override via environment variable
  local global_force="${FORCE_PUSH:-false}"

  # Resolve symlinks for the search root to ensure path consistency
  local resolved_root
  resolved_root=$(readlink -f "$search_root")

  [[ $debug == "true" ]] && echo "DEBUG: [Discovery] Scanning root: $resolved_root (Global Force: $global_force)" >&2

  echo "[]" > "$json_output"

  # -L allows find to follow symbolic links
  while IFS= read -r sync_file; do
    # Normalize the sync_file path
    sync_file=$(readlink -f "$sync_file")
    local sidecar_dir=$(dirname "$sync_file")
    local project_path="${sidecar_dir%-github-sync.d}"
    
    if [[ ! -d "$project_path" ]]; then
      [[ $debug == "true" ]] && echo "DEBUG: [Discovery] Skipping non-existent path: $project_path" >&2
      continue
    fi

    # Default values
    local repo_name=$(basename "$project_path")
    local private="true"
    local forcePush="$global_force"
    local githubPages="false"
    local githubPagesBranch="main"
    local githubPagesPath="/"

    # Source local overrides
    if [[ -s "$sync_file" ]]; then
      eval "$(grep -E '^[a-zA-Z_][a-zA-Z0-9_]*=' "$sync_file")"
    fi

    local project_json=$(jq -n \
      --arg path "$project_path" \
      --arg repo_name "$repo_name" \
      --arg private "$private" \
      --arg github_user "$github_user" \
      --arg forcePush "$forcePush" \
      --arg githubPages "$githubPages" \
      --arg githubPagesBranch "$githubPagesBranch" \
      --arg githubPagesPath "$githubPagesPath" \
      '{path: $path, repo_name: $repo_name, private: $private, github_user: $github_user, forcePush: $forcePush, githubPages: $githubPages, githubPagesBranch: $githubPagesBranch, githubPagesPath: $githubPagesPath}')

    jq ". += [$project_json]" "$json_output" > "${json_output}.tmp" && \mv "${json_output}.tmp" "$json_output"

  done < <(find -L "$resolved_root" -type d -name "*-github-sync.d" -exec test -f "{}/sync" \; -print | sed 's|$|/sync|')
}
