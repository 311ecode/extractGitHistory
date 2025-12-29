#!/usr/bin/env bash

git_path_transplant() {
  local meta_file="$1"
  local dest_path="$2"
  
  # Safety Checks
  [[ ! -f "$meta_file" ]] && echo "❌ Meta file not found" && return 1
  [[ -d "$dest_path" ]] && echo "❌ Destination $dest_path already exists" && return 1
  [[ -n "$(git status --porcelain)" ]] && echo "❌ Working tree is dirty" && return 1
  
  if git check-ignore -q "$dest_path"; then
    echo "❌ Destination path is ignored by git"
    return 1
  fi

  local extracted_repo=$(jq -r '.extracted_repo_path' "$meta_file")
  
  # WE KEEP SLASHES: Standard git allows branch names with slashes (acting as folders).
  # Tests (like testHashParityRoundTrip) rely on "history/path/to/file" structure.
  local branch_name="history/$dest_path"

  # 1. Fetch the extracted history into a local temporary branch
  # Use --force to ensure we have a clean pointer if the branch existed
  if ! git fetch "$extracted_repo" "HEAD:$branch_name" --force --quiet; then
    echo "❌ ERROR: Could not fetch from extracted repo."
    return 1
  fi

  # 2. Rewrite the history of that branch to sit under the new destination path
  if ! git filter-repo --refs "$branch_name" --to-subdirectory-filter "$dest_path" --force --quiet; then
    echo "❌ ERROR: git-filter-repo failed."
    return 1
  fi

  # Verify the branch still points to a valid commit
  if ! git rev-parse --verify "$branch_name" >/dev/null 2>&1; then
     echo "❌ ERROR: Filtered branch $branch_name lost or empty."
     return 1
  fi

  # 3. Apply the history to the current branch
  if [[ "${GIT_PATH_TRANSPLANT_USE_REBASE:-}" == "1" ]]; then
    # Rebase: Linear history
    if ! git rebase "$branch_name" --quiet; then
        echo "❌ ERROR: Rebase failed. Aborting."
        git rebase --abort 2>/dev/null
        return 1
    fi
  else
    # Default: Merge commit
    if ! git merge "$branch_name" --allow-unrelated-histories -m "graft: $dest_path history" --quiet; then
         echo "❌ ERROR: Merge failed."
         return 1
    fi
  fi

  # Note: We intentionally do NOT delete $branch_name here. 
  # Verification tests rely on this branch existing.
}
