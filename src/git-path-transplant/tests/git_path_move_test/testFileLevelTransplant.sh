#!/usr/bin/env bash

testFileLevelTransplant() {
  echo "🧪 Testing File-Level Transplant (Exact Path Matching)"
  
  push_state DEBUG "1"
  push_state PWD

  local tmp_dir=$(mktemp -d)
  local result=0

  (
    # 1. Setup Repo
    mkdir -p "$tmp_dir/repo/src"
    cd "$tmp_dir/repo" && git init -q
    git config user.email "test@test.com" && git config user.name "Tester"
    
    # 2. Create file with history
    echo "content v1" > src/original.txt
    git add . && git commit -m "feat: add original file" -q
    echo "content v2" > src/original.txt
    git add . && git commit -m "feat: update original file" -q
    
    # 3. Perform File Move: src/original.txt -> renamed.txt
    # This is the 'mv f/a d' scenario
    git_path_move "src/original.txt" "renamed.txt"
    
    # 4. VERIFICATION
    echo "🔍 Verifying file-level move results..."
    
    # Check for correct name (not renamed.txtoriginal.txt or original/original)
    if [[ ! -f "renamed.txt" ]]; then
      echo "❌ ERROR: Destination file 'renamed.txt' missing."
      ls -R
      exit 1
    fi

    if [[ -d "renamed.txt" ]]; then
      echo "❌ ERROR: Destination is a directory, should be a file."
      exit 1
    fi

    if [[ -f "src/original.txt" ]]; then
      echo "❌ ERROR: Source file still exists (should be moved)."
      exit 1
    fi

    # Check History
    local history_count=$(git log --oneline -- renamed.txt | wc -l)
    if [[ $history_count -lt 2 ]]; then
      echo "❌ ERROR: History lost. Expected 2 commits, found $history_count."
      exit 1
    fi

    echo "✅ SUCCESS: File-level transplant verified with history."
    exit 0
  )
  result=$?

  rm -rf "$tmp_dir"
  pop_state PWD
  pop_state DEBUG
  return $result
}
