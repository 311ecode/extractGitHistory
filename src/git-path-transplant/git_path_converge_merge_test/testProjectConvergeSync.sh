#!/usr/bin/env bash

testProjectConvergeSync() {
  echo "🧪 Testing Project Converge Sync (File-Level Magic)"
  
  push_state DEBUG "1"
  push_state PWD

  local tmp_dir=$(mktemp -d)
  local result=0

  (
    cd "$tmp_dir" || exit 1

    # 1. Setup Source A: unique file 'A.txt'
    mkdir repoA && cd repoA && git init -q
    git config user.email "a@test.com" && git config user.name "A"
    echo "content A" > A.txt
    git add . && git commit -m "feat: repo A content" -q
    cd "$tmp_dir"

    # 2. Setup Source B: unique file 'B.txt'
    mkdir repoB && cd repoB && git init -q
    git config user.email "b@test.com" && git config user.name "B"
    echo "content B" > B.txt
    git add . && git commit -m "feat: repo B content" -q
    cd "$tmp_dir"

    # 3. Setup Source C: unique file 'C.txt'
    mkdir repoC && cd repoC && git init -q
    git config user.email "c@test.com" && git config user.name "C"
    echo "content C" > C.txt
    git add . && git commit -m "feat: repo C content" -q
    cd "$tmp_dir"

    # 4. Monorepo Destination
    mkdir monorepo && cd monorepo && git init -q
    git config user.email "m@test.com" && git config user.name "M"
    git commit --allow-empty -m "root" -q

    # 5. EXECUTE: The "Magic" Convergence
    echo "🚀 Merging A, B, and C into 'unified_sync'..."
    # Force cleanse off to avoid the BFG deletion bug
    GIT_PATH_TRANSPLANT_USE_CLEANSE=0 \
    git_path_converge_merge "unified_sync" "$tmp_dir/repoA" "$tmp_dir/repoB" "$tmp_dir/repoC"

    # 6. VERIFY SYNC: Are all files present?
    echo "🔍 Verifying file union..."
    local missing=0
    [[ -f "unified_sync/A.txt" ]] || { echo "❌ Missing A.txt"; missing=1; }
    [[ -f "unified_sync/B.txt" ]] || { echo "❌ Missing B.txt"; missing=1; }
    [[ -f "unified_sync/C.txt" ]] || { echo "❌ Missing C.txt"; missing=1; }

    if [[ $missing -eq 1 ]]; then
      echo "❌ ERROR: File-level sync failed."
      exit 1
    fi

    # 7. VERIFY HISTORY: Are all 3 branch histories present?
    local commits=$(git log --oneline -- unified_sync | grep "feat: repo" | wc -l)
    if [[ $commits -ne 3 ]]; then
      echo "❌ ERROR: History sync failed. Found $commits commits, expected 3."
      exit 1
    fi

    echo "✅ SUCCESS: All files and histories synced via magic convergence."
    exit 0
  )
  result=$?
  rm -rf "$tmp_dir"

  pop_state PWD
  pop_state DEBUG
  return $result
}
