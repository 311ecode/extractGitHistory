#!/usr/bin/env bash
github_sync_workflow_process_projects_helper() {
  local project="$1"
  local dry_run="$2"
  local debug="$3"

  if [[ $debug == "1" ]]; then debug="true"; fi

  # Use local to prevent leakage/overwriting
  local github_user=$(echo "$project" | jq -r '.github_user')
  local project_path=$(echo "$project" | jq -r '.path') # Renamed to project_path for clarity
  local repo_name=$(echo "$project" | jq -r '.repo_name')
  local private=$(echo "$project" | jq -r '.private')
  local forcePush=$(echo "$project" | jq -r '.forcePush')
  local githubPages=$(echo "$project" | jq -r '.githubPages')
  local githubPagesBranch=$(echo "$project" | jq -r '.githubPagesBranch')
  local githubPagesPath=$(echo "$project" | jq -r '.githubPagesPath')

  if [[ $debug == "true" ]]; then
    echo "DEBUG: [HELPER_IN] Targeting Path: '$project_path'" >&2
    echo "DEBUG: [HELPER_IN] Visibility: '$private'" >&2
  fi

  # CRITICAL: Verify the path exists before calling git tools
  if [[ ! -d $project_path ]]; then
    echo "ERROR: Target path does not exist or is not a directory: $project_path" >&2
    return 1
  fi

  local stderr_capture=$(mktemp)
  local meta_file

  # Call extraction on the specific project_path
  meta_file=$(gitHistoryTools_extractGitPath "$project_path" 2>"$stderr_capture")
  local extract_exit_code=$?

  if [[ $extract_exit_code -ne 0 ]]; then
    echo "ERROR: Git extraction failed for $project_path" >&2
    cat "$stderr_capture" >&2
    rm -f "$stderr_capture"
    return 1
  fi
  rm -f "$stderr_capture"

  # Inject custom settings into meta.json
  local temp_meta=$(mktemp)
  jq --arg repo_name "$repo_name" \
    --arg private "$private" \
    --arg forcePush "$forcePush" \
    --arg githubPages "$githubPages" \
    --arg githubPagesBranch "$githubPagesBranch" \
    --arg githubPagesPath "$githubPagesPath" \
    '.custom_repo_name = $repo_name | 
        .custom_private = $private | 
        .custom_forcePush = $forcePush |
        .custom_githubPages = $githubPages |
        .custom_githubPagesBranch = $githubPagesBranch |
        .custom_githubPagesPath = $githubPagesPath' \
    "$meta_file" >"$temp_meta"
  mv "$temp_meta" "$meta_file"

  if [[ $debug == "true" ]]; then
    echo "DEBUG: [META_INJECTED] Meta file: $meta_file" >&2
    echo "DEBUG: [META_INJECTED] custom_private: $(jq -r '.custom_private' "$meta_file")" >&2
  fi

  export DEBUG="$debug"
  local github_url
  github_url=$(github_pusher "$meta_file" "$dry_run" 2>&1)
  local pusher_exit_code=$?

  if [[ $pusher_exit_code -ne 0 ]]; then
    echo "$github_url" >&2
    return 1
  fi
  echo "✓ Successfully synced: $github_url" >&2
  return 0
}
