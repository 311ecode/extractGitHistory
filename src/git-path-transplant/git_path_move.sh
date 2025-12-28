#!/usr/bin/env bash

git_path_move() {
  local from_path="$1"
  local to_path="$2"
  local act_like_cp="${ACT_LIKE_CP:-0}"

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
  local abs_to_path
  abs_to_path=$(cd "$to_dir_part" && pwd)/"$to_base_part"
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

  if [[ -z "$source_repo_root" ]]; then
    echo "ERROR: Source path is not inside a git repository: $abs_from_path" >&2
    return 1
  fi

  # 3. Extract History
  local meta_file
  meta_file=$(extract_git_path "$abs_from_path")
  if [[ $? -ne 0 || ! -f "$meta_file" ]]; then return 1; fi

  # Find the Git repo root for the destination
  local dest_search_dir="$abs_to_path"
  [[ ! -d "$dest_search_dir" ]] && dest_search_dir=$(dirname "$dest_search_dir")
  
  local dest_repo_root=""
  while [[ "$dest_search_dir" != "/" ]]; do
    if [[ -d "$dest_search_dir/.git" ]]; then
      dest_repo_root="$dest_search_dir"
      break
    fi
    dest_search_dir="$(dirname "$dest_search_dir")"
  done

  local rel_dest_path="${abs_to_path#$dest_repo_root/}"
  rel_dest_path="${rel_dest_path#/}"

  # 4. Transplant
  ( cd "$dest_repo_root" && git_path_transplant "$meta_file" "$rel_dest_path" )

  # 5. Handle Logic
  if [[ "$source_repo_root" == "$dest_repo_root" ]]; then
    cd "$dest_repo_root" || return 1
    
    # NEW: Only remove if not acting like CP
    if [[ "$act_like_cp" == "1" ]]; then
      echo "📂 Copying history to $to_path (Source preserved)..."
    else
      echo "🔄 Moving history to $to_path (Source removed)..."
      rm -rf "$abs_from_path"
    fi
    
    local branch_name="history/$rel_dest_path"
    if git merge "$branch_name" --allow-unrelated-histories --no-edit; then
      local action="Moved"
      [[ "$act_like_cp" == "1" ]] && action="Copied"
      echo "✨ $action $from_path to $to_path (History preserved)"
    else
      echo "⚠️  Merge conflict occurred. Please resolve and commit."
    fi
  else
    echo "📦 Inter-repo transplant complete. History available on branch: history/$rel_dest_path"
  fi

  rm -rf "$(dirname "$meta_file")"
  return 0
}
