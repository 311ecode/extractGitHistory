#!/usr/bin/env bash

testRelativeUpwardMove() {
  echo "🧪 Testing Relative Upward Move (../../ context)"
  
  push_state PWD
  push_state DEBUG "1"
  push_state GIT_PATH_TRANSPLANT_ACT_LIKE_CP "0"
  push_state GIT_PATH_TRANSPLANT_USE_CLEANSE "0"

  local tmp_dir=$(mktemp -d)
  local result=0

  (
    # Setup: repo/level1/level2/target_dir
    mkdir -p "$tmp_dir/repo/level1/level2/target_dir"
    cd "$tmp_dir/repo" && git init -q
    git config user.email "test@test.com" && git config user.name "Tester"
    
    echo "data" > level1/level2/target_dir/file.txt
    git add . && git commit -m "feat: nested data" -q

    # Navigate deep
    cd level1/level2/target_dir || exit 1
    
    # MOVE: target_dir -> ../../archive/legacy 
    # (Results in repo/level1/archive/legacy)
    git_path_move "." "../../archive/legacy"

    # VERIFICATION
    cd "$tmp_dir/repo" || exit 1

    if [[ -d "level1/level2/target_dir" ]]; then
      echo "❌ ERROR: Source directory level1/level2/target_dir still exists."
      exit 1
    fi

    # Corrected path: relative to repo root, it's now in level1/
    if [[ ! -f "level1/archive/legacy/file.txt" ]]; then
      echo "❌ ERROR: Destination file missing at level1/archive/legacy/file.txt"
      ls -R # Debugging helper if it fails again
      exit 1
    fi

    echo "✅ SUCCESS: Upward relative move verified at level1/archive/legacy."
    exit 0
  )
  result=$?

  pop_state GIT_PATH_TRANSPLANT_USE_CLEANSE
  pop_state GIT_PATH_TRANSPLANT_ACT_LIKE_CP
  pop_state DEBUG
  pop_state PWD

  return $result
}
