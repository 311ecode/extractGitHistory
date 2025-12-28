#!/usr/bin/env bash

git_path_move() {
  local from_path="$1"
  local to_path="$2"
  local debug="${DEBUG:-}"

  if [[ $# -ne 2 ]]; then
    echo "ERROR: Usage: git_path_move <from_path> <to_path>" >&2
    return 1
  fi

  # Resolve absolute paths
  local abs_from_path
  abs_from_path=$(cd "$(dirname "$from_path")" 2>/dev/null && pwd)/$(basename "$from_path")
  
  # 1. Extract
  local meta_file
  meta_file=$(extract_git_path "$from_path")
  if [[ $? -ne 0 || ! -f "$meta_file" ]]; then return 1; fi

  # 2. Identify Context & Destination
  local source_repo_root
  source_repo_root=$(jq -r '.original_repo_root' "$meta_file")
  
  local abs_to_path
  [[ "$to_path" = /* ]] && abs_to_path="$to_path" || abs_to_path="$(pwd)/$to_path"
  
  # Find the nearest existing parent to determine the repo root
  local search_dir="$abs_to_path"
  local dest_repo_root=""
  while [[ "$search_dir" != "/" ]]; do
    if [[ -d "$search_dir/.git" ]]; then
      dest_repo_root="$search_dir"
      break
    fi
    search_dir="$(dirname "$search_dir")"
  done

  if [[ -z "$dest_repo_root" ]]; then
    echo "ERROR: Destination is not inside a git repository." >&2
    return 1
  fi

  # Calculate relative path within repo
  local rel_dest_path="${abs_to_path#$dest_repo_root/}"

  # 3. Create missing parent directories in destination
  local dest_parent=$(dirname "$abs_to_path")
  if [[ ! -d "$dest_parent" ]]; then
    [[ -n "$debug" ]] && echo "DEBUG: Creating directory structure: $dest_parent" >&2
    mkdir -p "$dest_parent"
  fi

  # 4. Transplant (Creates the 'history/...' branch)
  ( cd "$dest_repo_root" && git_path_transplant "$meta_file" "$rel_dest_path" )

  # 5. Handle Intra-repo vs Inter-repo logic
  if [[ "$source_repo_root" == "$dest_repo_root" ]]; then
    echo "🔄 Completing intra-repo move..."
    
    # Remove old directory
    rm -rf "$abs_from_path"
    
    # Merge the new history
    local branch_name="history/$rel_dest_path"
    if git merge "$branch_name" --allow-unrelated-histories --no-edit; then
      echo "✨ Moved $from_path to $to_path (Hierarchy created, History preserved)"
    else
      echo "⚠️  Merge conflict occurred. Please resolve and commit."
    fi
  else
    echo "📦 Inter-repo transplant complete. History available on branch: history/$rel_dest_path"
    echo "💡 To finalize, run: git merge history/$rel_dest_path --allow-unrelated-histories"
  fi

  # Cleanup temp files
  rm -rf "$(dirname "$meta_file")"
  return 0
}
