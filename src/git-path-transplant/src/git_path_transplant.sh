#!/usr/bin/env bash

_log_debug() { [[ -n "${DEBUG:-}" ]] && echo "[DEBUG] $*" >&2; }

git_path_transplant() {
  local meta_file="$1"
  local dest_path="$2"

  local use_cleanse="${GIT_PATH_TRANSPLANT_USE_CLEANSE:-0}"
  local cleanse_hook="${GIT_PATH_TRANSPLANT_CLEANSE_HOOK:-}"

  _log_debug "--- Starting git_path_transplant ---"
  [[ ! -f "$meta_file" ]] && { echo "❌ Meta file missing"; return 1; }

  local extracted_repo=$(jq -r '.extracted_repo_path' "$meta_file")
  local original_rel_path=$(jq -r '.relative_path' "$meta_file")
  local branch_name="${GIT_PATH_TRANSPLANT_HISTORY_BRANCH:-history/transplant-default-$(date +%s)}"

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
    _log_debug "Working tree is dirty. Stashing local changes..."
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

  # 5. Determine if source is a File or Directory
  local is_dir=0
  if [[ "$original_rel_path" == "." || -d "$extracted_repo/$original_rel_path" ]]; then
    is_dir=1
  fi

  # 6. Rewrite
  if [[ $is_dir -eq 1 ]]; then
    git filter-repo --refs "$branch_name" --to-subdirectory-filter "$dest_path" --force --quiet
  else
    local src_filename=$(basename "$original_rel_path")
    git filter-repo --refs "$branch_name" \
      --filename-callback "return b'$dest_path' if filename == b'$src_filename' else filename" \
      --force --quiet
  fi

  # 7. Grafting (Merge Replacement)
  git rm -rf --cached "$dest_path" &>/dev/null || true

  if ! git merge "$branch_name" --allow-unrelated-histories -X theirs -m "graft: $dest_path history" --quiet; then
      _log_debug "Forcing alignment for $dest_path"
      git checkout "$branch_name" -- "$dest_path"
      git add "$dest_path"
      git commit -m "graft: $dest_path (forced)" --quiet
  fi

  # 8. RESTORE: STASH POP
  if [[ $stashed -eq 1 ]]; then
    _log_debug "Restoring stashed changes..."
    git stash pop --quiet || echo "⚠️  Stash pop resulted in conflicts."
  fi

  # 9. Cleanup (Cleanse) - Guaranteed to have stashed=0 here due to step 1
  if [[ "$use_cleanse" == "1" ]]; then
    local can_cleanse=true
    if [[ -n "$cleanse_hook" ]]; then
      "$cleanse_hook" "$original_rel_path" "$dest_path" "$meta_file" || can_cleanse=false
    fi
    [[ "$can_cleanse" == "true" ]] && command -v git-cleanse &>/dev/null && git-cleanse --yes "$original_rel_path"
  fi

  echo "✅ Successfully transplanted history to $dest_path"
}
