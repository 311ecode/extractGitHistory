#!/usr/bin/env bash

testRelativeUpwardMoveWithCleanse() {
  echo "🧪 Testing Relative Upward Move with Rebase and Cleanse"
  
  # 1. SETUP STATE
  # Force rebase and cleanse to test the complex logic path
  push_state GIT_PATH_TRANSPLANT_USE_REBASE "1"
  push_state GIT_PATH_TRANSPLANT_USE_CLEANSE "1"
  push_state DEBUG "1"
  push_state PWD

  local tmp_dir=$(mktemp -d)
  local result=0

  (
    # 2. Setup Directory Structure
    # Initial: 
    # /a/b/c.txt
    # /d/e/f.txt
    mkdir -p "$tmp_dir/repo/a/b"
    mkdir -p "$tmp_dir/repo/d/e"
    cd "$tmp_dir/repo" && git init -q
    git config user.email "test@test.com" && git config user.name "Tester"

    echo "content c" > a/b/c.txt
    git add . && git commit -m "feat: initial a/b/c" -q

    echo "content f" > d/e/f.txt
    git add . && git commit -m "feat: initial d/e/f" -q
    echo "update f" >> d/e/f.txt
    git add . && git commit -m "feat: update d/e/f" -q

    # 3. NAVIGATE TO /d
    # This specifically tests relative path resolution from a subdirectory
    cd d || exit 1

    # EXECUTE: mv e ../a/
    # Intended result: d/e/f.txt -> a/e/f.txt
    echo "🚀 Executing move: mv e ../a/"
    git_mv_shaded "e" "../a/"

    # 4. VERIFICATION
    cd "$tmp_dir/repo" || exit 1

    echo "🔍 Verifying file placement..."
    if [[ ! -f "a/e/f.txt" ]]; then
      echo "❌ ERROR: File f.txt not found at expected destination 'a/e/f.txt'"
      ls -R
      exit 1
    fi

    if [[ -d "d/e" ]]; then
      echo "❌ ERROR: Source directory 'd/e' still exists. Cleanup failed."
      exit 1
    fi

    # Verify existing files in 'a' were not disturbed
    if [[ ! -f "a/b/c.txt" ]]; then
      echo "❌ ERROR: Collision destroyed existing file 'a/b/c.txt'!"
      exit 1
    fi

    echo "🔍 Verifying history (Rebase & Cleanse)..."
    
    # Check that history of f.txt exists at new location
    local hist_count=$(git log --oneline -- a/e/f.txt | wc -l)
    if [[ $hist_count -lt 2 ]]; then
      echo "❌ ERROR: History failed to transplant. Found $hist_count commits."
      exit 1
    fi

    # Check for Cleanse: History for the OLD path should be scrubbed
    # We check the log of the exact file path that was removed
    if git log --all -- "d/e/f.txt" | grep -q "feat:"; then
      echo "❌ ERROR: Cleanse failed. History still visible at old path 'd/e/f.txt'"
      exit 1
    fi

    # Check for Rebase linearity
    local merge_commits=$(git rev-list --merges HEAD | wc -l)
    if [[ $merge_commits -ne 0 ]]; then
      echo "❌ ERROR: Rebase failed. Found $merge_commits merge commits."
      exit 1
    fi

    echo "✅ SUCCESS: Relative upward move with rebase and cleanse verified."
    exit 0
  )
  result=$?

  rm -rf "$tmp_dir"
  pop_state PWD
  pop_state DEBUG
  pop_state GIT_PATH_TRANSPLANT_USE_CLEANSE
  pop_state GIT_PATH_TRANSPLANT_USE_REBASE

  return $result
}
