#!/usr/bin/env bash
# Date: 2026-01-30

github_sync_discover_projects2() {
  local search_root="${1:-.}"
  local json_output="$2"
  local github_user="${GITHUB_USER:-$GITHUB_TEST_ORG}"
  local debug="${DEBUG:-false}"

  [[ $debug == "true" ]] && echo "DEBUG: [Discovery] Scanning root: $search_root" >&2

  echo "[]" > "$json_output"

  while IFS= read -r sync_file; do
    local sidecar_dir=$(dirname "$sync_file")
    local project_path="${sidecar_dir%-github-sync.d}"
    
    if [[ ! -d "$project_path" ]]; then
      [[ $debug == "true" ]] && echo "DEBUG: [Discovery] Skipping $sidecar_dir; $project_path not found." >&2
      continue
    fi

    # Defaults
    local repo_name=$(basename "$project_path")
    local private="true"
    local forcePush="false"
    local githubPages="false"
    local githubPagesBranch="main"
    local githubPagesPath="/"

    # Source local overrides
    if [[ -s "$sync_file" ]]; then
      # Extracting assignments safely
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

    jq ". += [$project_json]" "$json_output" > "${json_output}.tmp" && mv "${json_output}.tmp" "$json_output"

  done < <(find "$search_root" -type d -name "*-github-sync.d" -exec test -f "{}/sync" \; -print | sed 's|$|/sync|')
}
