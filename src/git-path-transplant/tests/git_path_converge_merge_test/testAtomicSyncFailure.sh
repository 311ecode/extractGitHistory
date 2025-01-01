#!/usr/bin/env bash

testAtomicSyncFailure() {
  echo "🧪 Testing Atomic Sync Failure (Physical Backup Protection)"
  
  push_state DEBUG "1"
  push_state PWD

  local tmp_dir=$(mktemp -d)
  local script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

  (
    cd "$tmp_dir" || exit 1

    # Setup Conflicting Source
    mkdir repoA && cd repoA && git init -q
    echo "Version A" > conflict.txt
    git add . && git commit -m "init A" -q
    cd "$tmp_dir"

    # Setup Monorepo
    mkdir monorepo && cd monorepo && git init -q
    mkdir my_app
    echo "Version Mono" > my_app/conflict.txt
    git add . && git commit -m "init Mono" -q
    
    # EXECUTE
    source "$script_dir/git_path_converge_merge.sh"
    source "$script_dir/git_path_sync_all.sh"
    
    git_path_sync_all "my_app" "$tmp_dir/repoA"
    
    # VERIFY
    echo "🔍 Verifying physical restoration..."
    
    local content=$(cat my_app/conflict.txt 2>/dev/null)
    if [[ "$content" != "Version Mono" ]]; then
      echo "❌ ERROR: Content missing! Restoration failed."
      exit 1
    fi

    echo "✅ SUCCESS: Atomic protection verified via Physical Backup."
    exit 0
  )
  local result=$?
  rm -rf "$tmp_dir"
  pop_state PWD
  pop_state DEBUG
  return $result
}
