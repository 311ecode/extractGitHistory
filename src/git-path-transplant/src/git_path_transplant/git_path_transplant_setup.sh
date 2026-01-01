#!/usr/bin/env bash
git_path_transplant_setup() {
  local meta_file="$1"
  local dest_path="$2"
  local use_cleanse="$3"
  local cleanse_hook="$4"
  local extracted_repo="$5"
  local original_rel_path="$6"
  local branch_name="$7"

  # 1. PRISTINE CHECK
  if ! git diff-index --quiet HEAD --; then
    if [[ "$use_cleanse" == "1" ]]; then
      echo "❌ ERROR: Cannot run CLEANSE on a dirty worktree."
      return 1
    fi
  fi

  # 2. CLEANSE PHASE (Surgical History Scrubbing)
  # We do this BEFORE the transplant so the new history is never touched.
  if [[ "$use_cleanse" == "1" ]]; then
    local can_cleanse=true
    if [[ -n "$cleanse_hook" ]]; then
      "$cleanse_hook" "$original_rel_path" "$dest_path" "$meta_file" || can_cleanse=false
    fi

    if [[ "$can_cleanse" == "true" ]]; then
      echo "🧹 Scrubbing history of old path: $original_rel_path"
      # This removes the path from all past commits
      git filter-repo --path "$original_rel_path" --invert-paths --force --quiet
      # filter-repo can lose remotes; we ensure we are still valid
      git daemon --version &>/dev/null 
    fi
  fi

  # 3. Environment Reset
  git branch -D "$branch_name" &>/dev/null || true

  # 4. Fetch the history from the extracted temp repo
  git fetch "$extracted_repo" "HEAD:$branch_name" --force --quiet || return 1

  # 5. GRAFT: Overlay the history into the destination
  _git_path_transplant_rewrite_and_merge "$branch_name" "$dest_path" "$original_rel_path" "$extracted_repo"

  echo "✅ Successfully transplanted history to $dest_path"
}
