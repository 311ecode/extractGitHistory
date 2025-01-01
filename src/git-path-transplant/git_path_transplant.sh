#!/usr/bin/env bash

_log_debug() { [[ -n "${DEBUG:-}" ]] && echo "[DEBUG] $*" >&2; }

git_path_transplant() {
  local meta_file="$1"
  local dest_path="$2"

  local use_cleanse="${GIT_PATH_TRANSPLANT_USE_CLEANSE:-0}"
  local cleanse_hook="${GIT_PATH_TRANSPLANT_CLEANSE_HOOK:-}"

  _log_debug "--- Starting git_path_transplant ---"
  [[ ! -f "$meta_file" ]] && { echo "❌ Meta file missing"; return 1; }
  [[ -d "$dest_path" ]] && { echo "❌ Destination already exists"; return 1; }

  local extracted_repo
  extracted_repo=$(jq -r '.extracted_repo_path' "$meta_file")

  local original_rel_path
  original_rel_path=$(jq -r '.relative_path' "$meta_file")

  # ───────────────────────────────────────────────────────────────
  # Use the sanitized branch name exported by git_path_move
  # Fall back to a safe default only if not set
  # ───────────────────────────────────────────────────────────────
  local branch_name="${GIT_PATH_TRANSPLANT_HISTORY_BRANCH:-history/transplant-default-$(date +%s)}"

  _log_debug "Using branch name for fetch: $branch_name"

  git fetch "$extracted_repo" "HEAD:$branch_name" --force --quiet || {
    echo "❌ Failed to fetch from extracted repo using branch: $branch_name"
    return 1
  }

  git filter-repo --refs "$branch_name" --to-subdirectory-filter "$dest_path" --force --quiet || return 1

  if [[ "${GIT_PATH_TRANSPLANT_USE_REBASE:-}" == "1" ]]; then
    _log_debug "Applying history via REBASE"
    git rebase "$branch_name" --quiet || { git rebase --abort 2>/dev/null; return 1; }
  else
    _log_debug "Applying history via MERGE"
    git merge "$branch_name" --allow-unrelated-histories -m "graft: $dest_path history" --quiet || return 1
  fi

  if [[ "$use_cleanse" == "1" ]]; then
    local can_cleanse=true
    if [[ -n "$cleanse_hook" ]]; then
      "$cleanse_hook" "$original_rel_path" "$dest_path" "$meta_file" || can_cleanse=false
    fi
    if [[ "$can_cleanse" == "true" ]]; then
      git-cleanse --yes "$original_rel_path"
    fi
  fi

  echo "✅ Successfully transplanted history to $dest_path"
}

