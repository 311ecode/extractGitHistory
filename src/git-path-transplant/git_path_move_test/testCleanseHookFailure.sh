#!/usr/bin/env bash

testCleanseHookFailure() {
  echo "🧪 Testing Cleanse Hook Failure (Environment Protected)"
  
  # DECLARE THE FUNCTION FIRST
  my_failing_hook() {
    echo "🔍 Hook: Blocking cleanse for $1"
    return 1 
  }
  # THEN EXPORT IT
  export -f my_failing_hook

  push_state GIT_PATH_TRANSPLANT_USE_CLEANSE "1"
  push_state GIT_PATH_TRANSPLANT_CLEANSE_HOOK "my_failing_hook"

  local tmp_dir=$(mktemp -d)
  local result=0

  (
    cd "$tmp_dir" && git init -q
    git config user.email "test@test.com" && git config user.name "Tester"
    mkdir -p "src_dir"
    echo "data" > src_dir/file.txt && git add . && git commit -m "init" -q

    git_path_move "src_dir" "dst_dir"

    if git log --all -- "src_dir" | grep -q "init"; then
      echo "✅ SUCCESS: Hook blocked the cleanse."
      exit 0
    else
      echo "❌ ERROR: History was scrubbed!"
      exit 1
    fi
  )
  result=$?

  pop_state GIT_PATH_TRANSPLANT_CLEANSE_HOOK
  pop_state GIT_PATH_TRANSPLANT_USE_CLEANSE
  unset -f my_failing_hook
  return $result
}
