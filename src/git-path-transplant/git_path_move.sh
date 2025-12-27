#!/usr/bin/env bash

git_path_move() {
  local from_path="$1"
  local to_path="$2"
  local debug="${DEBUG:-}"

  if [[ $# -ne 2 ]]; then
    echo "ERROR: Usage: git_path_move <from_path> <to_path>" >&2
    return 1
  fi

  # 1. Extract the path history
  [[ -n "$debug" ]] && echo "DEBUG: Extracting history from: $from_path" >&2
  local meta_file
  meta_file=$(extract_git_path "$from_path")
  
  if [[ $? -ne 0 || ! -f "$meta_file" ]]; then
    echo "ERROR: Failed to extract history for $from_path" >&2
    return 1
  fi

  # 2. Identify the destination repository context
  # If to_path is relative, it's relative to current PWD
  local abs_to_path
  if [[ "$to_path" = /* ]]; then
    abs_to_path="$to_path"
  else
    abs_to_path="$(pwd)/$to_path"
  fi

  # Determine destination repo root and relative path inside it
  local dest_dir="$abs_to_path"
  local dest_repo_root=""
  
  # Ensure the parent directory exists so we can find the repo root
  local search_dir
  search_dir=$(dirname "$abs_to_path")
  
  while [[ "$search_dir" != "/" ]]; do
    if [[ -d "$search_dir/.git" ]]; then
      dest_repo_root="$search_dir"
      break
    fi
    search_dir="$(dirname "$search_dir")"
  done

  if [[ -z "$dest_repo_root" ]]; then
    echo "ERROR: Destination path is not inside a git repository: $to_path" >&2
    return 1
  fi

  # Calculate the relative path within the destination repo
  local rel_dest_path
  if [[ "$abs_to_path" == "$dest_repo_root" ]]; then
    rel_dest_path="."
  else
    rel_dest_path="${abs_to_path#$dest_repo_root/}"
  fi

  # 3. Transplant the history
  [[ -n "$debug" ]] && echo "DEBUG: Transplanting to: $rel_dest_path in $dest_repo_root" >&2
  
  # Navigate to dest repo for the transplant operation
  (
    cd "$dest_repo_root" || exit 1
    git_path_transplant "$meta_file" "$rel_dest_path"
  )

  # 4. Cleanup
  local temp_dir
  temp_dir=$(dirname "$meta_file")
  [[ -n "$debug" ]] && echo "DEBUG: Cleaning up temporary files in $temp_dir" >&2
  rm -rf "$temp_dir"

  return 0
}
