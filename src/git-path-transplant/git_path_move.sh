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

  # 1. Resolve Absolute Paths
  local abs_from_path
  abs_from_path=$(mkdir -p "$(dirname "$from_path")" && cd "$(dirname "$from_path")" && pwd -P)/$(basename "$from_path")
  abs_from_path=$(realpath -m "$abs_from_path" 2>/dev/null || echo "$abs_from_path")

  local to_dir_part=$(dirname "$to_path")
  mkdir -p "$to_dir_part"
  local abs_to_path=$(cd "$to_dir_part" 2>/dev/null && pwd -P)/$(basename "$to_path")
  abs_to_path=$(realpath -m "$abs_to_path" 2>/dev/null || echo "$abs_to_path")

  # 2. Find source repo root
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

  # 3. Create SAFE branch name - only [a-z0-9_-]  (no spaces, no emojis, no ?)
  local timestamp=$(date +%Y%m%d-%H%M%S)
  local slug
  slug=$(echo "$to_path" \
    | tr -cs 'a-zA-Z0-9' '-' \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/^-+//;s/-+$//;s/-+/-/g' \
    | cut -c1-40)

  [[ -z "$slug" ]] && slug="unknown-path"

  local safe_branch_name="history/transplant-${timestamp}-${slug}"

  # Debug output to confirm the branch name being used
  [[ -n "${DEBUG:-}" ]] && {
    echo "DEBUG: Original destination path: '$to_path'" >&2
    echo "DEBUG: Generated slug: '$slug'" >&2
    echo "DEBUG: Using safe branch name: $safe_branch_name" >&2
  }

  export GIT_PATH_TRANSPLANT_HISTORY_BRANCH="$safe_branch_name"

  # 4. Extract metadata
  local meta_file
  meta_file=$(extract_git_path "$abs_from_path") || return 1

  # 5. Destination repo root & relative path
  local dest_repo_root
  dest_repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
  [[ -z "$dest_repo_root" ]] && { echo "ERROR: Current directory not in git repo" >&2; return 1; }

  local rel_dest_path="${abs_to_path#$dest_repo_root/}"
  rel_dest_path="${rel_dest_path#/}"

  # 6. Transplant in subshell (with explicit export for safety)
  (
    export GIT_PATH_TRANSPLANT_USE_CLEANSE="$use_cleanse"
    export GIT_PATH_TRANSPLANT_CLEANSE_HOOK="$cleanse_hook"
    export GIT_PATH_TRANSPLANT_HISTORY_BRANCH="$safe_branch_name"
    
    [[ -n "${DEBUG:-}" ]] && echo "DEBUG: Inside subshell - branch name: $GIT_PATH_TRANSPLANT_HISTORY_BRANCH" >&2
    
    cd "$dest_repo_root" && git_path_transplant "$meta_file" "$rel_dest_path"
  ) || return 1

  # 7. Cleanup source if intra-repo move
  if [[ "$source_repo_root" == "$dest_repo_root" ]]; then
    if [[ "$act_like_cp" != "1" ]]; then
      if [[ -d "$abs_from_path" ]]; then
        local leftovers=$(ls -A "$abs_from_path" 2>/dev/null)
        [[ -n "$leftovers" ]] && cp -rn "$abs_from_path/." "$abs_to_path/" 2>/dev/null
        rm -rf "$abs_from_path"
        git rm -rf --quiet "$abs_from_path" 2>/dev/null || true
      elif [[ -e "$abs_from_path" ]]; then
        rm -f "$abs_from_path"
        git rm --quiet "$abs_from_path" 2>/dev/null || true
      fi
    fi
  fi

  # 8. Clean up temporary extraction directory
  rm -rf "$(dirname "$meta_file")"

  return 0
}

