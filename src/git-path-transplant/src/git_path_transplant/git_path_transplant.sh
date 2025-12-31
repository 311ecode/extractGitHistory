#!/usr/bin/env bash



git_path_transplant() {
  local meta_file="$1"
  local dest_path="$2"

  local use_cleanse="${GIT_PATH_TRANSPLANT_USE_CLEANSE:-0}"
  local cleanse_hook="${GIT_PATH_TRANSPLANT_CLEANSE_HOOK:-}"

  _log_debug_git_path_transplant "--- Starting git_path_transplant ---"
  [[ ! -f "$meta_file" ]] && { echo "❌ Meta file missing"; return 1; }

  local extracted_repo=$(jq -r '.extracted_repo_path' "$meta_file")
  local original_rel_path=$(jq -r '.relative_path' "$meta_file")
  local branch_name="${GIT_PATH_TRANSPLANT_HISTORY_BRANCH:-history/transplant-default-$(date +%s)}"

  # Call the setup function
  git_path_transplant_setup "$meta_file" "$dest_path" "$use_cleanse" "$cleanse_hook" "$extracted_repo" "$original_rel_path" "$branch_name"
}


