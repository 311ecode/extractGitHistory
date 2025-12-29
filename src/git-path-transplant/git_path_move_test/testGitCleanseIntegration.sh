#!/usr/bin/env bash

testGitCleanseIntegration() {
  echo "🧪 Testing Git Cleanse Integration (Deep Cleanse Check)"
  local tmp_dir=$(mktemp -d)
  cd "$tmp_dir" && git init -q
  git config user.email "tester@test.com" && git config user.name "Tester"

  # 1. Create source with history
  mkdir -p "sensitive_dir"
  echo "v1" > sensitive_dir/data.txt && git add . && git commit -m "commit 1" -q
  echo "v2" > sensitive_dir/data.txt && git add . && git commit -m "commit 2" -q

  # 2. Run move with CLEANSE enabled
  export GIT_PATH_TRANSPLANT_USE_CLEANSE=1
  git_path_move "sensitive_dir" "new_home"
  unset GIT_PATH_TRANSPLANT_USE_CLEANSE

  # 3. Verify Filesystem
  [[ -d "sensitive_dir" ]] && echo "❌ ERROR: Source dir still exists" && return 1
  [[ ! -f "new_home/data.txt" ]] && echo "❌ ERROR: Dest file missing" && return 1

  # 4. Verify History Scrub (The Deep Check)
  echo "🔍 Checking for ghost history of 'sensitive_dir'..."
  # If git-cleanse worked, the old path should have zero commits in the log
  local history_line_count
  history_line_count=$(git log --all -- "sensitive_dir" | wc -l)
  
  if [[ $history_line_count -gt 0 ]]; then
    echo "❌ ERROR: Deep cleanse failed! History for 'sensitive_dir' still exists."
    return 1
  fi

  # 5. Verify History Preservation at Destination
  local dest_history_count
  dest_history_count=$(git log --oneline -- "new_home" | wc -l)
  if [[ $dest_history_count -lt 2 ]]; then
    echo "❌ ERROR: History not transplanted to new_home."
    return 1
  fi

  echo "✅ SUCCESS: Deep cleanse verified. Source history wiped, dest history preserved."
  return 0
}
