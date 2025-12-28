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

  # 2. Identify Context
  local source_repo_root
  source_repo_root=$(jq -r '.original_repo_root' "$meta_file")
  
  # Determine destination repo root
  local abs_to_path
  [[ "$to_path" = /* ]] && abs_to_path="$to_path" || abs_to_path="$(pwd)/$to_path"
  
  local search_dir=$(dirname "$abs_to_path")
  local dest_repo_root=""
  while [[ "$search_dir" != "/" ]]; do
    [[ -d "$search_dir/.git" ]] && dest_repo_root="$search_dir" && break
    search_dir="$(dirname "$search_dir")"
  done

  # 3. Transplant (Creates the 'history/...' branch)
  local rel_dest_path="${abs_to_path#$dest_repo_root/}"
  ( cd "$dest_repo_root" && git_path_transplant "$meta_file" "$rel_dest_path" )

  # 4. Intra-repo specific: Make the move "Real"
  if [[ "$source_repo_root" == "$dest_repo_root" ]]; then
    echo "🔄 Completing intra-repo move..."
    
    # Remove old directory
    rm -rf "$abs_from_path"
    
    # Merge the new history so the folder 'b' actually appears
    local branch_name="history/$rel_dest_path"
    if git merge "$branch_name" --allow-unrelated-histories --no-edit; then
      echo "✨ Moved $from_path to $to_path (History preserved)"
    else
      echo "⚠️  Merge conflict occurred. Please resolve and commit."
    fi
  else
    echo "📦 Inter-repo transplant complete. History available on branch: history/$rel_dest_path"
    echo "💡 To finalize, run: git merge history/$rel_dest_path --allow-unrelated-histories"
  fi

  # 5. Cleanup temp files
  rm -rf "$(dirname "$meta_file")"
  return 0
}
