#!/usr/bin/env bash
git_path_transplant_setup() {
  local meta_file="$1"
  local dest_path="$2"
  local use_cleanse="$3"
  local cleanse_hook="$4"
  local extracted_repo="$5"
  local original_rel_path="$6"
  local branch_name="$7"

  # 1. PRISTINE CHECK & AUTO-STASH
  local is_dirty=0
  if ! git diff-index --quiet HEAD --; then
    is_dirty=1
    # If Cleanse is ON, we must abort because BFG/filter-repo on main repo is destructive
    if [[ "$use_cleanse" == "1" ]]; then
      echo "❌ ERROR: Cannot run CLEANSE on a dirty worktree."
      return 1
    fi
  fi

  local stashed=0
  if [[ $is_dirty -eq 1 ]]; then
    _log_debug_git_path_transplant "Working tree is dirty. Stashing local changes..."
    git stash push -m "temp-stash-transplant" --include-untracked --quiet
    stashed=1
  fi

  # 2. CLEANSE PHASE (Surgical History Scrubbing)
  if [[ "$use_cleanse" == "1" ]]; then
    local can_cleanse=true
    if [[ -n "$cleanse_hook" ]]; then
      "$cleanse_hook" "$original_rel_path" "$dest_path" "$meta_file" || can_cleanse=false
    fi

    if [[ "$can_cleanse" == "true" ]]; then
      echo "🧹 Scrubbing history of old path: $original_rel_path"
      git filter-repo --path "$original_rel_path" --invert-paths --force --quiet
      # filter-repo can lose remotes; we ensure we are still valid
      git daemon --version &>/dev/null 
    fi
  fi

  # 3. Environment Reset
  git branch -D "$branch_name" &>/dev/null || true

  # 4. Fetch the history from the extracted temp repo
  git fetch "$extracted_repo" "HEAD:$branch_name" --force --quiet || {
    [[ $stashed -eq 1 ]] && git stash pop --quiet
    return 1
  }

  # 5. GRAFT: Overlay the history into the destination
  _git_path_transplant_rewrite_and_merge "$branch_name" "$dest_path" "$original_rel_path" "$extracted_repo"

  # 6. RESTORE STASH
  if [[ $stashed -eq 1 ]]; then
    _log_debug_git_path_transplant "Restoring stashed changes..."
    git stash pop --quiet || echo "⚠️ Stash pop resulted in conflicts."
  fi

  echo "✅ Successfully transplanted history to $dest_path"
}
