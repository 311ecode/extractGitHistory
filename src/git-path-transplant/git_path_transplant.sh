#!/usr/bin/env bash

_log_debug() {
  if [[ -n "${DEBUG:-}" ]]; then
    echo "[DEBUG] $*" >&2
  fi
}

git_path_transplant() {
  local meta_file="$1"
  local dest_path="$2"
  local use_cleanse="${GIT_PATH_TRANSPLANT_USE_CLEANSE:-0}"
  
  _log_debug "--- Starting git_path_transplant ---"
  _log_debug "GIT_PATH_TRANSPLANT_USE_CLEANSE: '$use_cleanse'"

  # Safety Checks
  if [[ ! -f "$meta_file" ]]; then
     echo "❌ Meta file not found" && return 1
  fi

  if [[ -d "$dest_path" ]]; then 
     echo "❌ Destination $dest_path already exists" && return 1
  fi

  if [[ -n "$(git status --porcelain)" ]]; then
     echo "❌ Working tree is dirty" && return 1
  fi

  # 1. Resolve Metadata
  local extracted_repo
  local original_rel_path
  extracted_repo=$(jq -r '.extracted_repo_path' "$meta_file")
  original_rel_path=$(jq -r '.relative_path' "$meta_file")
  
  local branch_name="history/$dest_path"

  # 2. Fetch & Filter
  if ! git fetch "$extracted_repo" "HEAD:$branch_name" --force --quiet; then
    echo "❌ ERROR: Could not fetch from extracted repo."
    return 1
  fi
  
  if ! git filter-repo --refs "$branch_name" --to-subdirectory-filter "$dest_path" --force --quiet; then
    echo "❌ ERROR: git-filter-repo failed."
    return 1
  fi

  # 3. Apply History
  if [[ "${GIT_PATH_TRANSPLANT_USE_REBASE:-}" == "1" ]]; then
    if ! git rebase "$branch_name" --quiet; then
        git rebase --abort 2>/dev/null
        return 1
    fi
  else
    if ! git merge "$branch_name" --allow-unrelated-histories -m "graft: $dest_path history" --quiet; then
         return 1
    fi
  fi
  
  # 4. Deep Cleanse (History Scrub)
  if [[ "$use_cleanse" == "1" ]]; then
    if git log -1 -- "$original_rel_path" &>/dev/null; then
      echo "🛡️  GIT_PATH_TRANSPLANT: Cleansing source '$original_rel_path' from history..."
      git-cleanse --yes "$original_rel_path"
    fi
  fi

  echo "✅ Successfully transplanted history to $dest_path"
}
