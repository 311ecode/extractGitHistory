#!/usr/bin/env bash

git_path_transplant() {
  command -v markdown-show-help-registration &>/dev/null && eval "$(markdown-show-help-registration --minimum-parameters 2)"
  local meta_file="$1"
  local dest_path="$2"

  # 1. Check if the working directory is dirty
  if [[ -n $(git status --porcelain) ]]; then
    echo "❌ ERROR: Working directory is dirty. Please commit or stash changes before transplanting." >&2
    return 1
  fi

  # 2. Check if destination exists or is ignored
  if [[ -e "$dest_path" ]]; then
    echo "❌ ERROR: Destination path '$dest_path' already exists." >&2
    return 1
  fi

  if git check-ignore -q "$dest_path"; then
    echo "❌ ERROR: Destination path '$dest_path' is ignored by git." >&2
    return 1
  fi

  
  local meta_json="$1"
  local destination_path="$2"
  local debug="${DEBUG:-}"

  # 1. Validation
  if [[ ! -f "$meta_json" ]]; then
    echo "❌ ERROR: Metadata file not found: $meta_json" >&2
    return 1
  fi

  # 2. Extract Metadata
  local extracted_repo
  extracted_repo=$(jq -r '.extracted_repo_path' "$meta_json")
  
  [[ -n "$debug" ]] && echo "🧪 DEBUG: Starting graft for $destination_path" >&2

  # 3. Path Re-prefixing (The "Re-Write")
  # We use filter-repo to move the flat extracted files into the destination folder.
  # This makes the commits in the temp repo "Monorepo-ready".
  (
    cd "$extracted_repo" || exit
    [[ -n "$debug" ]] && echo "🧪 DEBUG: Applying monorepo prefix: $destination_path" >&2
    git filter-repo --force --to-subdirectory-filter "$destination_path" --quiet
  )

  # 4. The Graft (No Merge)
  # We fetch the objects into the monorepo.
  git remote add transplant_source "$extracted_repo" 2>/dev/null || git remote set-url transplant_source "$extracted_repo"
  git fetch transplant_source --quiet

  # We identify the head of the transplanted history
  local source_head
  source_head=$(git rev-parse transplant_source/master 2>/dev/null || git rev-parse transplant_source/main)

  # Create a branch pointing EXACTLY at that history.
  # This branch has NO connection to your current 'main' history (it's an orphan).
  local branch_name="history/$destination_path"
  git branch -f "$branch_name" "$source_head"

  # Cleanup
  git remote remove transplant_source
  
  [[ -n "$debug" ]] && echo "✅ SUCCESS: History grafted onto branch $branch_name" >&2
  echo "💡 To view the history: git log $branch_name"
  echo "💡 To integrate into your current branch WITHOUT changing hashes, use: git merge $branch_name --allow-unrelated-histories"
  return 0
}
