#!/usr/bin/env bash

testDeepIntraRepoMove() {
  echo "🧪 Testing Deep Move (Pristine Environment Setup)"
  
  # 1. PUSH STATE: Define the sandbox variables
  # This ensures the test is independent of the user's current shell state
  push_state GIT_PATH_TRANSPLANT_USE_CLEANSE "0"
  push_state GIT_PATH_TRANSPLANT_ACT_LIKE_CP "0"
  push_state GIT_PATH_TRANSPLANT_CLEANSE_HOOK ""
  push_state DEBUG "1"
  push_state PWD

  local tmp_dir=$(mktemp -d)
  local result=0

  # 2. RUN TEST IN ISOLATION
  (
    mkdir -p "$tmp_dir/repo/src"
    cd "$tmp_dir/repo" && git init -q
    git config user.email "test@test.com" && git config user.name "Tester"
    
    echo "deep code" > src/app.js
    git add . && git commit -m "feat: initial" -q
    
    # Target is 4 levels deep
    local target="a/b/c/d"
    git_path_move "src" "$target"
    
    # 3. VERIFICATION
    if [[ ! -f "$target/app.js" ]]; then
      echo "❌ ERROR: File missing at deep target path."
      exit 1
    fi
    if [[ -d "src" ]]; then
      echo "❌ ERROR: Source directory 'src' not removed."
      exit 1
    fi
    echo "✅ SUCCESS: Deep move verified in pristine environment."
    exit 0
  )
  result=$?

  # 4. POP STATE: Restore the user's world
  pop_state PWD
  pop_state DEBUG
  pop_state GIT_PATH_TRANSPLANT_CLEANSE_HOOK
  pop_state GIT_PATH_TRANSPLANT_ACT_LIKE_CP
  pop_state GIT_PATH_TRANSPLANT_USE_CLEANSE

  return $result
}
