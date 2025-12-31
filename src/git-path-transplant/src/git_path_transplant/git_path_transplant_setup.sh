#!/usr/bin/env bash
git_path_transplant_setup() {
  local meta_file="$1"
  local dest_path="$2"
  local use_cleanse="$3"
  local cleanse_hook="$4"
  local extracted_repo="$5"
  local original_rel_path="$6"
  local branch_name="$7"

  # 1. PRISTINE CHECK FOR CLEANSE
  # If we are scrubbing history, the repo MUST be clean because BFG replaces .git
  local is_dirty=0
  if ! git diff-index --quiet HEAD --; then
    is_dirty=1
    if [[ "$use_cleanse" == "1" ]]; then
      echo "❌ ERROR: Cannot run CLEANSE on a dirty worktree."
      echo "💡 Uncommitted changes in files like '$(git diff --name-only | head -n 1)' would be lost."
      echo "💡 Please commit or stash manually, then retry."
      return 1
    fi
  fi

  # 2. AUTO-STASH (Only for non-cleanse transplant)
  local stashed=0
  if [[ $is_dirty -eq 1 ]]; then
    _log_debug_git_path_transplant "Working tree is dirty. Stashing local changes..."
    git stash push -m "temp-stash-transplant" --include-untracked --quiet
    stashed=1
  fi

  # 3. Reset Environment
  rm -rf .git/filter-repo
  git branch -D "$branch_name" &>/dev/null || true

  # 4. Isolated Fetch
  git fetch "$extracted_repo" "HEAD:$branch_name" --force --quiet || {
    [[ $stashed -eq 1 ]] && git stash pop --quiet
    return 1
  }

  # 5. Call the rewrite and merge function
  _git_path_transplant_rewrite_and_merge "$branch_name" "$dest_path" "$original_rel_path" "$extracted_repo"

  # 6. RESTORE: STASH POP
  if [[ $stashed -eq 1 ]]; then
    _log_debug_git_path_transplant "Restoring stashed changes..."
    git stash pop --quiet || echo "⚠️  Stash pop resulted in conflicts."
  fi

  # 7. Cleanup (Cleanse) - Guaranteed to have stashed=0 here due to step 1
  if [[ "$use_cleanse" == "1" ]]; then
    local can_cleanse=true
    if [[ -n "$cleanse_hook" ]]; then
      "$cleanse_hook" "$original_rel_path" "$dest_path" "$meta_file" || can_cleanse=false
    fi
    [[ "$can_cleanse" == "true" ]] && command -v git-cleanse &>/dev/null && git-cleanse --yes "$original_rel_path"
  fi

  echo "✅ Successfully transplanted history to $dest_path"
}