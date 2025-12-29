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

  # 1. Resolve Absolute Paths and Normalize
  local abs_from_path
  abs_from_path=$(mkdir -p "$(dirname "$from_path")" && cd "$(dirname "$from_path")" && pwd)/$(basename "$from_path")
  abs_from_path=$(realpath -m "$abs_from_path")
  
  local to_dir_part=$(dirname "$to_path")
  local to_base_part=$(basename "$to_path")
  mkdir -p "$to_dir_part"
  local abs_to_path=$(cd "$to_dir_part" && pwd)/"$to_base_part"
  abs_to_path=$(realpath -m "$abs_to_path")

  # 2. Identify Context and Repo Roots
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
  meta_file=$(extract_git_path "$abs_from_path")
  [[ $? -ne 0 || ! -f "$meta_file" ]] && return 1

  # Resolve destination relative to its own repo root
  local dest_search_dir="$abs_to_path"
  [[ ! -d "$dest_search_dir" ]] && dest_search_dir=$(dirname "$dest_search_dir")
  local dest_repo_root=""
  while [[ "$dest_search_dir" != "/" ]]; do
    [[ -d "$dest_search_dir/.git" ]] && dest_repo_root="$dest_search_dir" && break
    dest_search_dir="$(dirname "$dest_search_dir")"
  done

  local rel_dest_path="${abs_to_path#$dest_repo_root/}"
  rel_dest_path="${rel_dest_path#/}"

  # 4. Transplant with Hook Propagation
  local effective_cleanse="$use_cleanse"
  [[ "$act_like_cp" == "1" ]] && effective_cleanse="0"

  ( 
    export GIT_PATH_TRANSPLANT_USE_CLEANSE="$effective_cleanse"
    export GIT_PATH_TRANSPLANT_CLEANSE_HOOK="$cleanse_hook"
    cd "$dest_repo_root" && git_path_transplant "$meta_file" "$rel_dest_path" 
  ) || return 1

  # 5. Local Cleanup (Filesystem only)
  if [[ "$source_repo_root" == "$dest_repo_root" && "$act_like_cp" != "1" ]]; then
    cd "$dest_repo_root" || return 1
    if [[ -e "$abs_from_path" ]]; then
      # If history wasn't scrubbed by a hook failure, we still remove the file pointer
      rm -rf "$abs_from_path"
      git rm -rf "$abs_from_path" &>/dev/null || true
    fi
  fi

  rm -rf "$(dirname "$meta_file")"
}
