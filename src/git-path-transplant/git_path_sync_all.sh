#!/usr/bin/env bash

git_path_sync_all() {
  local unified_path="$1"
  shift
  local source_repos=("$@")

  echo "🌀 Starting Invincible Ultimate Sync..."

  # 1. PHYSICAL BACKUP
  # We take a physical copy because git-filter-repo is too aggressive for branches/stash
  local backup_dir=$(mktemp -d)
  cp -ra "$unified_path/." "$backup_dir/" 2>/dev/null

  # 2. FORCE ENVIRONMENT
  export GIT_PATH_TRANSPLANT_USE_CLEANSE=0
  export GIT_PATH_TRANSPLANT_ACT_LIKE_CP=1

  # 3. SETUP TRIAL
  local temp_union="temp_union_$(date +%s)"
  
  # 4. ATOMIC TRIAL
  if ! git_path_converge_merge "$temp_union" "$unified_path" "${source_repos[@]}"; then
    echo ""
    echo "❌ ATOMIC ABORT: Conflict detected."
    echo "   Restoring Monorepo files from physical backup..."
    
    # Restore the files physically
    rm -rf "$unified_path"
    mkdir -p "$unified_path"
    cp -ra "$backup_dir/." "$unified_path/"
    
    # Clean up
    rm -rf "$backup_dir"
    [[ -d "$temp_union" ]] && rm -rf "$temp_union"
    
    # Reset index to make sure git knows the files are back
    git add "$unified_path"
    return 1
  fi

  # 5. FINALIZING
  echo "✅ Trial successful. Finalizing..."
  rm -rf "$backup_dir"

  rm -rf "$unified_path"
  mv "$temp_union" "$unified_path"
  git add "$unified_path"
  
  if ! git diff-index --quiet HEAD -- "$unified_path"; then
    git commit -m "sync: atomic convergence with ${#source_repos[@]} sources" --quiet
  fi

  # 6. CIRCLE BACK
  source "$(dirname "${BASH_SOURCE[0]}")/git_path_distribute_sync.sh"
  git_path_distribute_sync "$unified_path" "${source_repos[@]}"

  echo "✨ SYNC COMPLETE."
}
