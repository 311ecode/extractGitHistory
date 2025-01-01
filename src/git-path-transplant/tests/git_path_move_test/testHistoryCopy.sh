#!/usr/bin/env bash

testHistoryCopy() {
  echo "🧪 Testing History Copy (GIT_PATH_TRANSPLANT_ACT_LIKE_CP=1)"
  
  # 1. SETUP STATE
  push_state GIT_PATH_TRANSPLANT_ACT_LIKE_CP "1"
  push_state GIT_PATH_TRANSPLANT_USE_CLEANSE "0"
  push_state DEBUG "1"
  push_state PWD

  local tmp_dir=$(mktemp -d)
  local result=0

  (
    mkdir -p "$tmp_dir/repo/feature_dir"
    cd "$tmp_dir/repo" && git init -q
    git config user.email "test@test.com" && git config user.name "Tester"

    echo "v1" > feature_dir/app.log && git add . && git commit -m "c1" -q
    echo "v2" >> feature_dir/app.log && git add . && git commit -m "c2" -q

    # Execute move (acting like cp)
    git_path_move "feature_dir" "legacy_backup"

    # 2. VERIFICATION
    if [[ ! -d "feature_dir" ]]; then
      echo "❌ ERROR: Source deleted! ACT_LIKE_CP was ignored."
      exit 1
    fi
    if [[ ! -d "legacy_backup" ]]; then
      echo "❌ ERROR: Destination missing!"
      exit 1
    fi

    # Check history depth at destination
    local dest_count=$(git log --oneline -- "legacy_backup" | wc -l)
    if [[ $dest_count -lt 2 ]]; then
      echo "❌ ERROR: History not copied. Found $dest_count commits."
      exit 1
    fi

    echo "✅ SUCCESS: History successfully forked (Source preserved)."
    exit 0
  )
  result=$?

  # 3. RESTORE STATE
  pop_state PWD
  pop_state DEBUG
  pop_state GIT_PATH_TRANSPLANT_USE_CLEANSE
  pop_state GIT_PATH_TRANSPLANT_ACT_LIKE_CP

  return $result
}
