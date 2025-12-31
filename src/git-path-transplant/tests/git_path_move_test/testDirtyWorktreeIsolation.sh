#!/usr/bin/env bash

testDirtyWorktreeIsolation() {
  echo "🧪 Testing Dirty Worktree Isolation (Anti-Accidental-Commit)"
  
  push_state DEBUG "1"
  push_state PWD
  # CRITICAL: Disable cleanse so the stash logic can actually run
  push_state GIT_PATH_TRANSPLANT_USE_CLEANSE "0"

  local tmp_dir=$(mktemp -d)
  local result=0

  (
    cd "$tmp_dir" && git init -q
    git config user.email "test@test.com" && git config user.name "Tester"
    
    # 1. Setup: Two unrelated files
    echo "target content" > target_file.txt
    echo "distraction content" > triple.sh
    git add . && git commit -m "init" -q
    
    # 2. Modify the 'distraction' file but DO NOT commit it
    echo "UNCOMMITTED EDIT" >> triple.sh
    
    # 3. Perform move on the OTHER file
    # This should trigger: Stash -> Move -> Pop
    git_path_move "target_file.txt" "moved_target.txt"
    
    # 4. VERIFICATION
    echo "🔍 Verifying isolation..."

    if [[ ! -f "moved_target.txt" ]]; then
      echo "❌ ERROR: Target file move failed."
      exit 1
    fi

    # Verify triple.sh is still dirty (not committed in the graft)
    if git diff --quiet HEAD -- triple.sh; then
      echo "❌ ERROR: Dirty changes in triple.sh were accidentally committed!"
      exit 1
    fi

    # Verify the edit survived the Stash/Pop cycle
    if ! grep -q "UNCOMMITTED EDIT" triple.sh; then
      echo "❌ ERROR: Dirty changes were lost during transplant cycle!"
      exit 1
    fi

    echo "✅ SUCCESS: Dirty worktree was isolated and restored correctly."
    exit 0
  )
  result=$?

  rm -rf "$tmp_dir"
  pop_state GIT_PATH_TRANSPLANT_USE_CLEANSE
  pop_state PWD
  pop_state DEBUG
  return $result
}
