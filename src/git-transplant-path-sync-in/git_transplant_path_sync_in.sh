#!/usr/bin/env bash

git_transplant_path_sync_in() {
  command -v markdown-show-help-registration &>/dev/null && eval "$(markdown-show-help-registration --minimum-parameters 2)"
  
  local meta_json="$1"
  local poly_url="$2"
  local debug="${DEBUG:-}"

  if [[ ! -f "$meta_json" ]]; then
    echo "❌ ERROR: Metadata file not found: $meta_json" >&2
    return 1
  fi

  # 1. Extract state
  local rel_path
  rel_path=$(jq -r '.relative_path' "$meta_json")
  local last_mono_hash
  last_mono_hash=$(jq -r '.git_transplant_path_sync_in.last_synced_mono_hash // empty' "$meta_json")
  
  [[ -n "$debug" ]] && echo "🧪 DEBUG: Syncing Polyrepo ($poly_url) -> Monorepo ($rel_path)" >&2

  # 2. Divergence Check
  local current_mono_hash
  current_mono_hash=$(git log -n 1 --pretty=format:%H -- "$rel_path" 2>/dev/null)
  
  if [[ -n "$last_mono_hash" && "$current_mono_hash" != "$last_mono_hash" ]]; then
    echo "❌ ERROR: Monorepo directory '$rel_path' has diverged since last sync." >&2
    return 1
  fi

  # 3. Fetch from Polyrepo
  local temp_remote="sync_remote_$(date +%s)"
  git remote add "$temp_remote" "$poly_url"
  git fetch "$temp_remote" --quiet

  # 4. Identify Polyrepo Head
  local poly_head
  poly_head=$(git rev-parse "$temp_remote/main" 2>/dev/null || git rev-parse "$temp_remote/master" 2>/dev/null)
  
  if [[ -z "$poly_head" ]]; then
    echo "❌ ERROR: Could not find main/master branch in $poly_url" >&2
    git remote remove "$temp_remote"
    return 1
  fi

  # 5. Merge Strategy
  # We use 'subtree' merge strategy or a recursive merge with path prefixing 
  # to ensure changes from the polyrepo (which are at the root) land in the rel_path.
  git merge -X subtree="$rel_path" "$poly_head" --allow-unrelated-histories --no-edit -m "sync-in: updates from polyrepo to $rel_path"

  # 6. Update Metadata
  local current_head
  current_head=$(git rev-parse HEAD)
  local cmd_str="git-transplant-path-sync-in $meta_json $poly_url"
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local updated_meta
  updated_meta=$(jq --arg poly "$poly_head" \
                    --arg mono "$current_head" \
                    --arg url "$poly_url" \
                    --arg cmd "$cmd_str" \
                    --arg ts "$timestamp" \
                    '.git_transplant_path_sync_in = {
                        "last_run_timestamp": $ts,
                        "remote_url": $url,
                        "last_synced_poly_hash": $poly,
                        "last_synced_mono_hash": $mono,
                        "command_used": $cmd
                      }' "$meta_json")
  
  echo "$updated_meta" > "$meta_json"
  git remote remove "$temp_remote"
  
  [[ -n "$debug" ]] && echo "✅ SUCCESS: Synced $poly_head into $rel_path" >&2
  return 0
}
