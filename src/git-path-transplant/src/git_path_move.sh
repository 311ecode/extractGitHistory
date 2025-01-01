#!/usr/bin/env bash

git_path_move() {
  local from_path="$1"
  local to_path="$2"
  local act_like_cp="${GIT_PATH_TRANSPLANT_ACT_LIKE_CP:-0}"
  local use_cleanse="${GIT_PATH_TRANSPLANT_USE_CLEANSE:-0}"
  local cleanse_hook="${GIT_PATH_TRANSPLANT_CLEANSE_HOOK:-}"

  if [[ $# -ne 2 ]]; then
    echo "ERROR: Usage: git_path_move <from_path> <to_path>" >&2
    return 1
  fi

  # 🔒 SAFETY OVERRIDE: Copying implies preserving the source.
  if [[ "$act_like_cp" == "1" ]]; then
    use_cleanse="0"
  fi

  # 1. Resolve Absolute Paths
  local abs_from_path=$(realpath -m "$from_path")
  local abs_to_path=$(realpath -m "$to_path")
  local from_basename=$(basename "$abs_from_path")

  # 2. Standard 'mv' behavior: If 'to' is a directory, move 'from' INSIDE it
  if [[ -d "$abs_to_path" ]]; then
    abs_to_path="$abs_to_path/$from_basename"
  fi

  # 3. Find source repo root
  local search_dir="$abs_from_path"
  [[ ! -d "$search_dir" ]] && search_dir=$(dirname "$search_dir")
  local source_repo_root=""
  while [[ "$search_dir" != "/" ]] && [[ -n "$search_dir" ]]; do
    if [[ -d "$search_dir/.git" ]]; then
      source_repo_root="$search_dir"
      break
    fi
    search_dir="$(dirname "$search_dir")"
  done
  [[ -z "$source_repo_root" ]] && { echo "ERROR: Source not inside a git repository" >&2; return 1; }

  # 4. Get Destination Repo Root
  local dest_repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
  [[ -z "$dest_repo_root" ]] && { echo "ERROR: Current directory not in git repo" >&2; return 1; }
  
  local rel_dest_path=$(python3 -c "import os; print(os.path.relpath('$abs_to_path', '$dest_repo_root'))")

  # 5. Create SAFE branch name
  local timestamp=$(date +%Y%m%d-%H%M%S)
  local slug=$(echo "$rel_dest_path" | tr -cs 'a-zA-Z0-9' '-' | tr '[:upper:]' '[:lower:]' | sed -E 's/^-+//;s/-+$//' | cut -c1-40)
  local safe_branch_name="history/transplant-${timestamp}-${slug}"
  export GIT_PATH_TRANSPLANT_HISTORY_BRANCH="$safe_branch_name"

  # 6. Extract
  local meta_file=$(extract_git_path "$abs_from_path") || return 1
  local original_rel_path=$(jq -r '.relative_path' "$meta_file")

  # 7. Transplant
  (
    export GIT_PATH_TRANSPLANT_USE_CLEANSE="$use_cleanse"
    export GIT_PATH_TRANSPLANT_CLEANSE_HOOK="$cleanse_hook"
    cd "$dest_repo_root" && git_path_transplant "$meta_file" "$rel_dest_path"
  ) || return 1

  # 8. Cleanup Source 
  # CRITICAL SAFETY: Only delete source if we are moving WITHIN the same repo.
  # For inter-repo moves, we leave the source repo untouched (act like export).
  if [[ "$act_like_cp" != "1" && "$source_repo_root" == "$dest_repo_root" ]]; then
     # Use the relative path to the repo root for git rm
     local rel_from_path=$(python3 -c "import os; print(os.path.relpath('$abs_from_path', '$dest_repo_root'))")
     git rm -rf --quiet "$rel_from_path" 2>/dev/null || rm -rf "$abs_from_path"
  fi

  rm -rf "$(dirname "$meta_file")"
  return 0
}
