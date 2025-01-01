#!/usr/bin/env bash

testConvergeMergeConflictHandling() {
  echo "🧪 Testing Convergent Merge Conflict Detection"
  
  push_state DEBUG "1"
  push_state PWD

  local tmp_dir=$(mktemp -d)
  local result=0

  (
    cd "$tmp_dir" || exit 1

    # Setup two repos with the SAME file name but DIFFERENT content
    mkdir repo1 && cd repo1 && git init -q
    git config user.email "c1@test.com" && git config user.name "C1"
    echo "content version 1" > conflict.txt
    git add . && git commit -m "v1" -q
    cd "$tmp_dir"

    mkdir repo2 && cd repo2 && git init -q
    git config user.email "c2@test.com" && git config user.name "C2"
    echo "content version 2" > conflict.txt
    git add . && git commit -m "v2" -q
    cd "$tmp_dir"

    mkdir monorepo && cd monorepo && git init -q
    git config user.email "t@test.com" && git config user.name "T"
    touch init && git add . && git commit -m "init" -q

    # Attempt to merge - this should fail during the internal workspace merge phase
    echo "🚀 Attempting conflicting merge..."
    git_path_converge_merge "conflicted_dir" "$tmp_dir/repo1" "$tmp_dir/repo2" 2>/dev/null
    
    if [[ $? -eq 0 ]]; then
      echo "❌ ERROR: Merge should have failed due to conflicts"
      exit 1
    fi

    echo "✅ SUCCESS: Conflict correctly detected and operation aborted."
    exit 0
  )
  result=$?
  rm -rf "$tmp_dir"

  pop_state PWD
  pop_state DEBUG
  return $result
}
