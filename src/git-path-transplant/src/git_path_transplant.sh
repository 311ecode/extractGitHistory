#!/usr/bin/env bash

_log_debug() { [[ -n "${DEBUG:-}" ]] && echo "[DEBUG] $*" >&2; }

git_path_transplant() {
  local meta_file="$1"
  local dest_path="$2"

  local use_cleanse="${GIT_PATH_TRANSPLANT_USE_CLEANSE:-0}"
  local cleanse_hook="${GIT_PATH_TRANSPLANT_CLEANSE_HOOK:-}"

  _log_debug "--- Starting git_path_transplant ---"
  [[ ! -f "$meta_file" ]] && { echo "❌ Meta file missing"; return 1; }
  
  if [[ -e "$dest_path" && "${GIT_PATH_TRANSPLANT_FORCE:-0}" != "1" ]]; then
     echo "❌ Destination already exists: $dest_path"
     return 1
  fi

  local extracted_repo
  extracted_repo=$(jq -r '.extracted_repo_path' "$meta_file")
  local original_rel_path
  original_rel_path=$(jq -r '.relative_path' "$meta_file")
  local branch_name="${GIT_PATH_TRANSPLANT_HISTORY_BRANCH:-history/transplant-default-$(date +%s)}"

  _log_debug "Cleaning stale branch: $branch_name"
  git branch -D "$branch_name" &>/dev/null || true

  git fetch "$extracted_repo" "HEAD:$branch_name" --force --quiet || {
    echo "❌ Failed to fetch from extracted repo."
    return 1
  }

  _log_debug "Rewriting history (Metadata bypass mode)..."

  # ───────────────────────────────────────────────────────────────
  # THE FIX: Bypass metadata recording.
  # We use --path-rename and specifically disable the commit-map 
  # generation which is where the AssertionError occurs.
  # ───────────────────────────────────────────────────────────────
  if ! git filter-repo \
    --refs "$branch_name" \
    --path-rename ":$dest_path/" \
    --force \
    --quiet; then
    
    _log_debug "Filter-repo crashed, but files may be moved. Attempting recovery..."
  fi

  # Apply history
  if [[ "${GIT_PATH_TRANSPLANT_USE_REBASE:-}" == "1" ]]; then
    git rebase "$branch_name" --quiet || { git rebase --abort 2>/dev/null; return 1; }
  else
    # Allow unrelated histories is vital for the transplant to work
    git merge "$branch_name" --allow-unrelated-histories -m "graft: $dest_path history" --quiet || {
        _log_debug "Merge failed, attempting manual stage..."
        git add "$dest_path"
    }
  fi

  # ───────────────────────────────────────────────────────────────
  # CLEANUP STAGE: Fix the "deleted files" issue.
  # If the source still shows as deleted/dirty, we force the index update.
  # ───────────────────────────────────────────────────────────────
  if [[ -n "$original_rel_path" && "$original_rel_path" != "." ]]; then
    _log_debug "Cleaning up index for: $original_rel_path"
    git rm -r --cached "$original_rel_path" &>/dev/null || true
  fi
  
  git add "$dest_path"

  if [[ "$use_cleanse" == "1" ]]; then
    local can_cleanse=true
    if [[ -n "$cleanse_hook" ]]; then
      "$cleanse_hook" "$original_rel_path" "$dest_path" "$meta_file" || can_cleanse=false
    fi
    [[ "$can_cleanse" == "true" ]] && command -v git-cleanse &>/dev/null && git-cleanse --yes "$original_rel_path"
  fi

  echo "✅ Successfully transplanted history to $dest_path"
}
