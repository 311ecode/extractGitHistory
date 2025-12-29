#!/usr/bin/env bash

# This is our mock hook function
# It simulates a failure (e.g., it didn't like the look of the new history)
my_failing_hook() {
  echo "🔍 Hook: Validating $1 vs $2..."
  echo "❌ Hook: Detected a mismatch! Blocking cleanse."
  return 1 
}

testCleanseHookFailure() {
  echo "🧪 Testing Cleanse Hook Failure (Safeguard Check)"
  local tmp_dir=$(mktemp -d)
  cd "$tmp_dir" && git init -q
  git config user.email "test@test.com" && git config user.name "Tester"

  # 1. Setup history
  mkdir -p "src_dir"
  echo "important" > src_dir/file.txt && git add . && git commit -m "init" -q

  # 2. Export the hook and set the environment variable
  export -f my_failing_hook
  export GIT_PATH_TRANSPLANT_USE_CLEANSE=1
  export GIT_PATH_TRANSPLANT_CLEANSE_HOOK="my_failing_hook"

  # 3. Run the move
  git_path_move "src_dir" "dst_dir"

  # 4. VERIFICATION
  echo "🔍 Verifying result..."
  
  # History Check: Since the hook failed, the history for 'src_dir' should STILL EXIST
  local src_history_count=$(git log --oneline -- "src_dir" | wc -l)
  
  if [[ $src_history_count -eq 0 ]]; then
    echo "❌ ERROR: History was scrubbed even though the hook failed!"
    return 1
  fi

  echo "✅ SUCCESS: Hook blocked the cleanse. Source history preserved as a fallback."
  
  # Cleanup env for other tests
  unset GIT_PATH_TRANSPLANT_USE_CLEANSE
  unset GIT_PATH_TRANSPLANT_CLEANSE_HOOK
  return 0
}
