#!/usr/bin/env bash

_git_path_transplant_rewrite_and_merge() {
  local branch_name="$1"
  local dest_path="$2"
  local original_rel_path="$3"
  local extracted_repo="$4"

  # 1. Determine if source was a File or Directory using heuristic
  local src_filename=$(basename "$original_rel_path")
  local is_dir=1
  
  if [[ -f "$extracted_repo/$src_filename" ]]; then
     is_dir=0
  fi

  # 2. Rewrite history to the new destination path
  if [[ $is_dir -eq 1 ]]; then
    _log_debug_git_path_transplant "Detected Directory Transplant. Moving all content to $dest_path"
    git filter-repo --refs "$branch_name" --to-subdirectory-filter "$dest_path" --force --quiet
  else
    _log_debug_git_path_transplant "Detected File Transplant. Renaming $src_filename to $dest_path"
    git filter-repo --refs "$branch_name" \
      --filename-callback "return b'$dest_path' if filename == b'$src_filename' else filename" \
      --force --quiet
  fi

  # 3. GRAFTING LOGIC
  
  # MODE A: Rebase (Linear History) via Cherry-Pick
  if [[ "${GIT_PATH_TRANSPLANT_USE_REBASE:-0}" == "1" ]]; then
      _log_debug_git_path_transplant "Rebasing (Linearizing) history from $branch_name..."
      
      # Get list of commits in chronological order (reverse)
      local commits=$(git rev-list --reverse "$branch_name")
      
      if [[ -n "$commits" ]]; then
          # Strategy 'theirs' ensures that if the file already exists (unlikely in a move), the new one wins.
          # We use cherry-pick to apply the commits one by one onto HEAD.
          if git cherry-pick --strategy=recursive -X theirs --keep-redundant-commits $commits 2>/dev/null; then
              return 0
          else
              _log_debug_git_path_transplant "Cherry-pick failed. Aborting and falling back to Merge Overlay."
              git cherry-pick --abort 2>/dev/null
          fi
      fi
  fi

  # MODE B: Merge Overlay (Preserves History Graph or Fallback)
  _log_debug_git_path_transplant "Overlaying history (Merge Strategy)..."
  
  mkdir -p "$(dirname "$dest_path")"
  
  # 1. Prepare Index: Checkout the content from the branch
  git checkout "$branch_name" -- .
  git add "$dest_path"
  
  # 2. Commit: Create a merge commit manually if changes exist
  if ! git diff-index --quiet HEAD --; then
      local tree=$(git write-tree)
      local parent1=$(git rev-parse HEAD)
      local parent2=$(git rev-parse "$branch_name")
      
      local commit_msg="graft: $dest_path history transplanted"
      
      # Create a commit object with two parents
      local new_commit=$(echo "$commit_msg" | git commit-tree "$tree" -p "$parent1" -p "$parent2")
      
      # Move current branch to this new commit
      git reset --hard "$new_commit"
  fi
}
