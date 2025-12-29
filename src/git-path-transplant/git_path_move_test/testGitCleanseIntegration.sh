#!/usr/bin/env bash

testGitCleanseIntegration() {
  echo "🧪 Testing Git Cleanse Integration (State Protected)"
  
  # 1. SAVE USER STATE
  push_state GIT_PATH_TRANSPLANT_USE_CLEANSE "1"
  push_state DEBUG "1" # Enable for the test log

  local tmp_dir=$(mktemp -d)
  cd "$tmp_dir" && git init -q
  git config user.email "tester@test.com" && git config user.name "Tester"

  # 2. Setup and Run
  mkdir -p "sensitive_dir"
  echo "v1" > sensitive_dir/data.txt && git add . && git commit -m "commit 1" -q
  
  git_path_move "sensitive_dir" "new_home"

  # 3. VERIFICATION
  local history_line_count=$(git log --all -- "sensitive_dir" | wc -l)
  local result=0
  if [[ $history_line_count -gt 0 ]]; then
    echo "❌ ERROR: Deep cleanse failed!"
    result=1
  else
    echo "✅ SUCCESS: Deep cleanse verified."
  fi

  # 4. RESTORE USER STATE
  pop_state DEBUG
  pop_state GIT_PATH_TRANSPLANT_USE_CLEANSE

  return $result
}
