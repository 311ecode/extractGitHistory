#!/usr/bin/env bash

# Helper function for debug logging
# Prints to stderr so it doesn't corrupt return values captured by callers
_log_debug() {
  if [[ -n "${DEBUG:-}" ]]; then
    echo "[DEBUG] $*" >&2
  fi
}

git_path_transplant() {
  local meta_file="$1"
  local dest_path="$2"
  
  _log_debug "--- Starting git_path_transplant ---"
  _log_debug "Input meta_file: '$meta_file'"
  _log_debug "Input dest_path: '$dest_path'"
  _log_debug "CWD: $(pwd)"

  # Safety Checks
  if [[ ! -f "$meta_file" ]]; then
     _log_debug "FAILED: Meta file check."
     echo "❌ Meta file not found" && return 1
  fi

  if [[ -d "$dest_path" ]]; then 
     _log_debug "FAILED: Destination path check."
     echo "❌ Destination $dest_path already exists" && return 1
  fi

  if [[ -n "$(git status --porcelain)" ]]; then
     _log_debug "FAILED: Dirty working tree check."
     # If debug is on, actually show what is dirty
     if [[ -n "${DEBUG:-}" ]]; then
       git status --porcelain >&2
     fi
     echo "❌ Working tree is dirty" && return 1
  fi
  
  if git check-ignore -q "$dest_path"; then
    _log_debug "FAILED: Git ignore check for '$dest_path'."
    echo "❌ Destination path is ignored by git"
    return 1
  fi

  local extracted_repo
  extracted_repo=$(jq -r '.extracted_repo_path' "$meta_file")
  _log_debug "Resolved extracted_repo: '$extracted_repo'"

  # WE KEEP SLASHES: Standard git allows branch names with slashes (acting as folders).
  # Tests (like testHashParityRoundTrip) rely on "history/path/to/file" structure.
  local branch_name="history/$dest_path"
  _log_debug "Calculated temporary branch name: '$branch_name'"

  # 1. Fetch the extracted history into a local temporary branch
  # Use --force to ensure we have a clean pointer if the branch existed
  _log_debug "Command: git fetch '$extracted_repo' 'HEAD:$branch_name' --force"
  if ! git fetch "$extracted_repo" "HEAD:$branch_name" --force --quiet; then
    echo "❌ ERROR: Could not fetch from extracted repo."
    return 1
  fi
  
  local fetch_head
  fetch_head=$(git rev-parse "$branch_name")
  _log_debug "Fetch successful. Branch '$branch_name' is at commit: $fetch_head"

  # 2. Rewrite the history of that branch to sit under the new destination path
  _log_debug "Command: git filter-repo --refs '$branch_name' --to-subdirectory-filter '$dest_path'"
  
  # Note: filter-repo can be verbose, if DEBUG is on, we might want to remove --quiet,
  # but strictly following your request, we keep logic same but log the attempt.
  if ! git filter-repo --refs "$branch_name" --to-subdirectory-filter "$dest_path" --force --quiet; then
    echo "❌ ERROR: git-filter-repo failed."
    return 1
  fi

  # Verify the branch still points to a valid commit
  if ! git rev-parse --verify "$branch_name" >/dev/null 2>&1; then
     echo "❌ ERROR: Filtered branch $branch_name lost or empty."
     return 1
  fi

  local rewritten_head
  rewritten_head=$(git rev-parse "$branch_name")
  _log_debug "Filter-repo successful. New root commit for graft: $rewritten_head"

  # 3. Apply the history to the current branch
  if [[ "${GIT_PATH_TRANSPLANT_USE_REBASE:-}" == "1" ]]; then
    _log_debug "Mode: REBASE detected via env var."
    _log_debug "Command: git rebase '$branch_name'"
    
    # Rebase: Linear history
    if ! git rebase "$branch_name" --quiet; then
        echo "❌ ERROR: Rebase failed. Aborting."
        _log_debug "Rebase failed. Attempting abort..."
        git rebase --abort 2>/dev/null
        return 1
    fi
  else
    _log_debug "Mode: MERGE (Default)."
    _log_debug "Command: git merge '$branch_name' --allow-unrelated-histories"
    
    # Default: Merge commit
    if ! git merge "$branch_name" --allow-unrelated-histories -m "graft: $dest_path history" --quiet; then
         echo "❌ ERROR: Merge failed."
         return 1
    fi
  fi
  
  local final_head
  final_head=$(git rev-parse HEAD)
  _log_debug "Transplant complete. HEAD is now at: $final_head"
  _log_debug "Leaving temporary branch '$branch_name' intact for verification."

  # Note: We intentionally do NOT delete $branch_name here. 
  # Verification tests rely on this branch existing.
}