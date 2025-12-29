#!/usr/bin/env bash

testRecursiveHistoryCopy() {
  echo "🧪 Testing Recursive History Copy (cp -r context)"
  
  # 1. DEFINE SANDBOX STATE
  # We force ACT_LIKE_CP to ensure we are testing a "Copy" operation
  push_state GIT_PATH_TRANSPLANT_ACT_LIKE_CP "1"
  push_state GIT_PATH_TRANSPLANT_USE_CLEANSE "0"
  push_state DEBUG "1"
  push_state PWD

  local tmp_dir=$(mktemp -d)
  local result=0

  (
    # 2. Setup Source Repo with nested history
    mkdir -p "$tmp_dir/repo/project/src"
    mkdir -p "$tmp_dir/repo/project/docs"
    cd "$tmp_dir/repo" && git init -q
    git config user.email "test@test.com" && git config user.name "Tester"

    echo "code" > project/src/main.js
    echo "manual" > project/docs/readme.md
    git add . && git commit -m "initial project structure" -q
    
    echo "update" >> project/src/main.js
    git add . && git commit -m "update src" -q

    # 3. Execute Recursive Copy
    # In a real scenario, this is called by 'cp -r project project_v2'
    git_path_move "project" "project_v2"

    # 4. VERIFICATION
    # Check if destination exists and has the full structure
    if [[ ! -f "project_v2/src/main.js" || ! -f "project_v2/docs/readme.md" ]]; then
      echo "❌ ERROR: Recursive structure not preserved in destination."
      exit 1
    fi

    # Check if source STILL exists (since ACT_LIKE_CP=1)
    if [[ ! -d "project" ]]; then
      echo "❌ ERROR: Source deleted! ACT_LIKE_CP=1 was ignored."
      exit 1
    fi

    # Check history depth at destination
    # It should have inherited the 2 commits
    local dest_history_count=$(git log --oneline -- "project_v2" | wc -l)
    if [[ $dest_history_count -lt 2 ]]; then
      echo "❌ ERROR: History not recursively copied. Found $dest_history_count commits."
      exit 1
    fi

    echo "✅ SUCCESS: 'cp -r' logic successfully forked directory history."
    exit 0
  )
  result=$?

  # 5. RESTORE ORIGINAL STATE
  pop_state PWD
  pop_state DEBUG
  pop_state GIT_PATH_TRANSPLANT_USE_CLEANSE
  pop_state GIT_PATH_TRANSPLANT_ACT_LIKE_CP

  return $result
}
