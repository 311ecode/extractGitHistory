#!/usr/bin/env bash

# Mock hook function: Returns failure to block the cleanse
my_failing_hook() {
  echo "🔍 Hook: Received params - Src: $1, Dst: $2"
  echo "❌ Hook: Simulated integrity check failed. Blocking cleanse."
  return 1 
}

testCleanseHookFailure() {
  echo "🧪 Testing Cleanse Hook Failure (Environment Protected)"
  
  # 1. SAVE & SET STATE
  # Protect the user's environment by pushing current states onto the stack
  push_state GIT_PATH_TRANSPLANT_USE_CLEANSE "1"
  push_state GIT_PATH_TRANSPLANT_CLEANSE_HOOK "my_failing_hook"
  export -f my_failing_hook

  local tmp_dir=$(mktemp -d)
  local result=0

  # Setup test repository
  (
    cd "$tmp_dir" && git init -q
    git config user.email "test@test.com" && git config user.name "Tester"
    mkdir -p "src_dir"
    echo "important data" > src_dir/file.txt
    git add . && git commit -m "initial commit" -q

    # 2. RUN THE MOVE
    # This should attempt to cleanse but get blocked by the hook
    git_path_move "src_dir" "dst_dir"

    # 3. VERIFICATION
    echo "🔍 Verifying history was NOT scrubbed..."
    local src_history_count=$(git log --all -- "src_dir" | wc -l)
    
    if [[ $src_history_count -eq 0 ]]; then
      echo "❌ ERROR: History was scrubbed! The hook failure was ignored."
      result=1
    else
      echo "✅ SUCCESS: Hook blocked the cleanse. History preserved."
      result=0
    fi
  )
  result=$?

  # 4. RESTORE STATE
  # Restore original variables to exactly how they were (even if they were unset)
  pop_state GIT_PATH_TRANSPLANT_CLEANSE_HOOK
  pop_state GIT_PATH_TRANSPLANT_USE_CLEANSE
  
  # Cleanup the function from the namespace
  unset -f my_failing_hook

  return $result
}
