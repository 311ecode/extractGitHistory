#!/usr/bin/env bash
# Date: 2026-01-30

github_sync_workflow2() {
  local search_root="${1:-.}"
  local dry_run="${2:-false}"
  local debug="${DEBUG:-false}"
  
  [[ $debug == "1" ]] && debug="true"
  local json_output="/tmp/.github-sync-output2.json"
  
  # 1. Discover using the new sidecar logic
  github_sync_discover_projects2 "$search_root" "$json_output" "$debug"

  if [[ ! -s $json_output ]] || [[ $(jq 'length' "$json_output") -eq 0 ]]; then
    echo "ERROR: No projects found in $search_root" >&2
    return 1
  fi

  # 2. Process using the EXISTING established engine
  github_sync_workflow_process_projects "$json_output" "$dry_run" "$debug"
}
