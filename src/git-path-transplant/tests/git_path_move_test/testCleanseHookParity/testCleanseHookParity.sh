#!/usr/bin/env bash

# REAL-WORLD HOOK EXAMPLE: Checks if source and dest match in file size


testCleanseHookParity() {
  echo "🧪 Testing Cleanse Hook with Parity Check"
  
  # Protect user env
  push_state GIT_PATH_TRANSPLANT_USE_CLEANSE "1"
  push_state GIT_PATH_TRANSPLANT_CLEANSE_HOOK "testCleanseHookParity_check_size_parity_hook"
  export -f testCleanseHookParity_check_size_parity_hook

  local tmp_dir=$(mktemp -d)
  local result=0

  (
    cd "$tmp_dir" && git init -q
    git config user.email "test@test.com" && git config user.name "Tester"
    
    mkdir -p "origin_data"
    echo "This is important content." > origin_data/file.txt
    git add . && git commit -m "init" -q

    # Run Move
    git_path_move "origin_data" "safe_data"

    # Verify history is GONE (Hook should have returned 0)
    local history_count=$(git log --all -- "origin_data" | wc -l)
    if [[ $history_count -eq 0 ]]; then
      echo "✅ SUCCESS: Parity check passed and history scrubbed."
      result=0
    else
      echo "❌ ERROR: History remains even though parity matched."
      result=1
    fi
  )
  result=$?

  pop_state GIT_PATH_TRANSPLANT_CLEANSE_HOOK
  pop_state GIT_PATH_TRANSPLANT_USE_CLEANSE
  unset -f testCleanseHookParity_check_size_parity_hook
  return $result
}
