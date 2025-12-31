#!/usr/bin/env bash
_git_path_transplant_rewrite_and_merge() {
  local branch_name="$1"
  local dest_path="$2"
  local original_rel_path="$3"
  local extracted_repo="$4"
  
  # Determine if source is a File or Directory
  local is_dir=0
  if [[ "$original_rel_path" == "." || -d "$extracted_repo/$original_rel_path" ]]; then
    is_dir=1
  fi

  # Rewrite
  if [[ $is_dir -eq 1 ]]; then
    git filter-repo --refs "$branch_name" --to-subdirectory-filter "$dest_path" --force --quiet
  else
    local src_filename=$(basename "$original_rel_path")
    git filter-repo --refs "$branch_name" \
      --filename-callback "return b'$dest_path' if filename == b'$src_filename' else filename" \
      --force --quiet
  fi

  # Grafting (Merge Replacement)
  git rm -rf --cached "$dest_path" &>/dev/null || true

  if ! git merge "$branch_name" --allow-unrelated-histories -X theirs -m "graft: $dest_path history" --quiet; then
      _log_debug_git_path_transplant "Forcing alignment for $dest_path"
      git checkout "$branch_name" -- "$dest_path"
      git add "$dest_path"
      git commit -m "graft: $dest_path (forced)" --quiet
  fi
}