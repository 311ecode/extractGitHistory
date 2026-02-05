#!/usr/bin/env bash
github_pusher_update_meta_json() {
  local meta_file="$1"
  local github_url="$2"
  local github_owner="$3"
  local github_repo="$4"
  local synced_by="$5"
  local debug="${6:-false}"

  if [[ $debug == "true" ]]; then
    echo "DEBUG: Updating meta.json with sync status" >&2
  fi

  local synced_at
  synced_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Use jq to update sync_status in place
  local temp_file
  temp_file=$(mktemp)

  jq \
    --arg url "$github_url" \
    --arg owner "$github_owner" \
    --arg repo "$github_repo" \
    --arg synced_at "$synced_at" \
    --arg synced_by "$synced_by" \
    '.sync_status.synced = true |
         .sync_status.github_url = $url |
         .sync_status.github_owner = $owner |
         .sync_status.github_repo = $repo |
         .sync_status.synced_at = $synced_at |
         .sync_status.synced_by = $synced_by' \
    "$meta_file" >"$temp_file"

  if [[ $? -eq 0 ]]; then
    \mv "$temp_file" "$meta_file"
    if [[ $debug == "true" ]]; then
      echo "DEBUG: Successfully updated meta.json" >&2
    fi
    return 0
  else
    echo "ERROR: Failed to update meta.json" >&2
    rm -f "$temp_file"
    return 1
  fi
}
