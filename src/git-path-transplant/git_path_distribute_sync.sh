#!/usr/bin/env bash

git_path_distribute_sync() {
  local unified_path="$1"
  shift
  local target_repos=("$@")

  echo "🔄 Starting Magic Circle Sync (Distributing changes back)..."

  if [[ ! -d "$unified_path" ]]; then
    echo "❌ ERROR: Unified path '$unified_path' not found." >&2
    return 1
  fi

  # 1. Extract the current unified state
  local meta
  meta=$(extract_git_path "$unified_path") || return 1
  local extracted_repo=$(jq -r '.extracted_repo_path' "$meta")

  # 2. Sync back to each target
  for repo_path in "${target_repos[@]}"; do
    local abs_repo_path=$(realpath "$repo_path")
    echo "📤 Syncing updates back to: $abs_repo_path"
    
    # Allow pushing to the current branch temporarily
    git -C "$abs_repo_path" config receive.denyCurrentBranch ignore

    (
      cd "$extracted_repo" || exit 1
      git push "$abs_repo_path" HEAD:master --force --quiet
    )
    
    if [[ $? -eq 0 ]]; then
      # Update the target's working directory to match the pushed history
      git -C "$abs_repo_path" reset --hard HEAD --quiet
      echo "✅ Successfully synced and reset $repo_path"
    else
      echo "❌ Failed to push to $repo_path"
    fi
    
    # Restore safety config
    git -C "$abs_repo_path" config receive.denyCurrentBranch refuse
  done

  rm -rf "$(dirname "$meta")"
}
