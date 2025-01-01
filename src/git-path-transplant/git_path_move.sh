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
  abs_from_path=$(mkdir -p "$(dirname "$from_path")" && cd "$(dirname "$from_path")" && pwd)/$(basename "$from_path")
  abs_from_path=$(realpath -m "$abs_from_path")
  
  local to_dir_part=$(dirname "$to_path")
  mkdir -p "$to_dir_part"
  local abs_to_path=$(cd "$to_dir_part" && pwd)/$(basename "$to_path")
  abs_to_path=$(realpath -m "$abs_to_path")

  # 2. Identify Source Repo Root
  local search_dir="$abs_from_path"
  [[ ! -d "$search_dir" ]] && search_dir=$(dirname "$search_dir")
  local source_repo_root=""
  while [[ "$search_dir" != "/" ]]; do
    if [[ -d "$search_dir/.git" ]]; then
      source_repo_root="$search_dir"
      break
    fi
    search_dir="$(dirname "$search_dir")"
  done

  [[ -z "$source_repo_root" ]] && { echo "ERROR: Source not in git repo" >&2; return 1; }

  # 3. Extract History
  local meta_file
  meta_file=$(extract_git_path "$abs_from_path") || return 1

  # 4. Identify Destination Repo Root
  local dest_repo_root
  dest_repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
  
  local rel_dest_path="${abs_to_path#$dest_repo_root/}"
  rel_dest_path="${rel_dest_path#/}"

  # 5. Transplant
  # We only allow effective cleanse if we are in the same repo
  local effective_cleanse="0"
  if [[ "$source_repo_root" == "$dest_repo_root" && "$act_like_cp" != "1" ]]; then
    effective_cleanse="$use_cleanse"
  fi

  ( 
    export GIT_PATH_TRANSPLANT_USE_CLEANSE="$effective_cleanse"
    export GIT_PATH_TRANSPLANT_CLEANSE_HOOK="$cleanse_hook"
    cd "$dest_repo_root" && git_path_transplant "$meta_file" "$rel_dest_path" 
  ) || return 1

  # 6. Safety-First Cleanup Logic
  # CRITICAL FIX: Only remove source if it is in the SAME repo and not in CP mode
  if [[ "$source_repo_root" == "$dest_repo_root" ]]; then
    if [[ "$act_like_cp" != "1" ]]; then
      if [[ "$effective_cleanse" == "1" ]]; then
         # Handled by git-cleanse inside transplant
         : 
      else
        # Standard move: remove the source folder/file
        rm -rf "$abs_from_path"
        git rm -rf "$abs_from_path" &>/dev/null || true
      fi
    fi
  else
    echo "📦 Inter-repo move detected: Source preserved for safety."
  fi

  rm -rf "$(dirname "$meta_file")"
}
