#!/usr/bin/env bash

git_path_move() {
  local from_path="$1"
  local to_path="$2"
  local debug="${DEBUG:-}"

  if [[ $# -ne 2 ]]; then
    echo "ERROR: Usage: git_path_move <from_path> <to_path>" >&2
    return 1
  fi

  # Resolve absolute paths for comparison
  local abs_from_path
  abs_from_path=$(cd "$(dirname "$from_path")" 2>/dev/null && pwd)/$(basename "$from_path")
  
  # 1. Extract the path history
  [[ -n "$debug" ]] && echo "DEBUG: Extracting history from: $abs_from_path" >&2
  local meta_file
  meta_file=$(extract_git_path "$from_path")
  
  if [[ $? -ne 0 || ! -f "$meta_file" ]]; then
    echo "ERROR: Failed to extract history for $from_path" >&2
    return 1
  fi

  # 2. Identify destination repo context
  local abs_to_path
  if [[ "$to_path" = /* ]]; then
    abs_to_path="$to_path"
  else
    abs_to_path="$(pwd)/$to_path"
  fi

  local search_dir=$(dirname "$abs_to_path")
  local dest_repo_root=""
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

  # Calculate relative path for the transplant
  local rel_dest_path
  if [[ "$abs_to_path" == "$dest_repo_root" ]]; then
    rel_dest_path="."
  else
    rel_dest_path="${abs_to_path#$dest_repo_root/}"
  fi

  # 3. Detect Intra-repo move and handle source deletion
  local source_repo_root
  source_repo_root=$(jq -r '.original_repo_root' "$meta_file")

  # 4. Transplant the history
  [[ -n "$debug" ]] && echo "DEBUG: Transplanting to: $rel_dest_path in $dest_repo_root" >&2
  (
    cd "$dest_repo_root" || exit 1
    git_path_transplant "$meta_file" "$rel_dest_path"
  )

  # 5. Same-repo cleanup: Delete source directory if roots match
  if [[ "$source_repo_root" == "$dest_repo_root" ]]; then
    [[ -n "$debug" ]] && echo "DEBUG: Same-repo move detected. Removing source: $abs_from_path" >&2
    if [[ -e "$abs_from_path" ]]; then
      rm -rf "$abs_from_path"
      echo "🗑️  Deleted source directory (same-repo move): $from_path"
    fi
  fi

  # 6. Final Cleanup of temp files
  local temp_dir=$(dirname "$meta_file")
  rm -rf "$temp_dir"

  echo "✅ Done. Use 'git status' to review and 'git merge history/$rel_dest_path --allow-unrelated-histories' to integrate."
  return 0
}
