#!/usr/bin/env bash

testGitCleanseIntegration() {
  echo "🧪 Testing Git Cleanse Integration (Deep History Scrub)"
  
  # 1. SETUP PRISTINE STATE
  # We force CLEANSE to 1, but ensure CP is 0 so they don't conflict.
  push_state GIT_PATH_TRANSPLANT_USE_CLEANSE "1"
  push_state GIT_PATH_TRANSPLANT_ACT_LIKE_CP "0"
  push_state DEBUG "1"
  push_state PWD

  local tmp_dir=$(mktemp -d)
  local result=0

  (
    cd "$tmp_dir" && git init -q
    git config user.email "cleaner@test.com" && git config user.name "Cleaner"

    # 2. Create history to be scrubbed
    mkdir -p "secret_data"
    echo "initial" > secret_data/file.txt && git add . && git commit -m "c1" -q
    echo "modified" > secret_data/file.txt && git add . && git commit -m "c2" -q

    # 3. RUN THE CLEANSE MOVE
    git_path_move "secret_data" "public_data"

    # 4. VERIFICATION
    echo "🔍 Verifying history scrub..."
    # If cleanse worked, this log should be empty
    local history_count=$(git log --all -- "secret_data" | wc -l)
    
    if [[ $history_count -ne 0 ]]; then
      echo "❌ ERROR: History for 'secret_data' still exists!"
      exit 1
    fi

    if [[ ! -f "public_data/file.txt" ]]; then
      echo "❌ ERROR: Destination file missing!"
      exit 1
    fi

    echo "✅ SUCCESS: Deep history scrub verified."
    exit 0
  )
  result=$?

  # 5. RESTORE ORIGINAL STATE
  pop_state PWD
  pop_state DEBUG
  pop_state GIT_PATH_TRANSPLANT_ACT_LIKE_CP
  pop_state GIT_PATH_TRANSPLANT_USE_CLEANSE

  return $result
}
