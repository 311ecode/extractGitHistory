#!/usr/bin/env bash

testHistoryParityMagic() {
  echo "🧪 Testing History Parity Magic (Metadata Mirroring)"
  
  # 1. DEFINE SANDBOX STATE
  # We freeze the identity and the move behavior
  push_state GIT_AUTHOR_NAME "Wizard"
  push_state GIT_AUTHOR_EMAIL "magic@test.com"
  push_state GIT_COMMITTER_NAME "Wizard"
  push_state GIT_COMMITTER_EMAIL "magic@test.com"
  
  # Use deterministic dates for the magic chain
  push_state GIT_AUTHOR_DATE "2025-01-01T12:00:00Z"
  push_state GIT_COMMITTER_DATE "2025-01-01T12:00:00Z"
  export GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL GIT_AUTHOR_DATE GIT_COMMITTER_DATE

  push_state GIT_PATH_TRANSPLANT_ACT_LIKE_CP "1" # Magic Copy behavior
  push_state GIT_PATH_TRANSPLANT_USE_CLEANSE "0"
  push_state DEBUG "1"
  push_state PWD

  local tmp_dir=$(mktemp -d)
  local result=0

  (
    cd "$tmp_dir" && git init -q
    git config user.email "magic@test.com" && git config user.name "Wizard"

    # 2. Create original history A -> B -> C
    mkdir -p "origin_dir"
    echo "A" > origin_dir/file.txt && git add . && git commit -m "Commit A" -q
    echo "B" >> origin_dir/file.txt && git add . && git commit -m "Commit B" -q
    echo "C" >> origin_dir/file.txt && git add . && git commit -m "Commit C" -q

    # 3. Perform the Magic Copy
    # This uses git_path_move with ACT_LIKE_CP=1
    git_path_move "origin_dir" "magic_copy"

    # 4. Verify Metadata Parity
    echo "🔍 Comparing Metadata Sequences..."
    
    # Format: Message|Author|Email (Dates are frozen so hashes should follow)
    local log_orig=$(git log --format="%s|%an|%ae" -- "origin_dir")
    local log_copy=$(git log --format="%s|%an|%ae" -- "magic_copy")

    if [[ "$log_orig" != "$log_copy" ]]; then
      echo "❌ ERROR: Metadata mismatch between source and copy!"
      echo "--- Original ---"
      echo "$log_orig"
      echo "--- Copy ---"
      echo "$log_copy"
      exit 1
    fi

    # 5. Verify Content Parity
    local final_content=$(cat magic_copy/file.txt)
    if [[ "$final_content" != *"C"* ]]; then
      echo "❌ ERROR: Content failed to transplant correctly."
      exit 1
    fi

    echo "✅ SUCCESS: Metadata mirror verified (A -> B -> C preserved)."
    exit 0
  )
  result=$?

  # 6. RESTORE ORIGINAL STATE
  pop_state PWD
  pop_state DEBUG
  pop_state GIT_PATH_TRANSPLANT_USE_CLEANSE
  pop_state GIT_PATH_TRANSPLANT_ACT_LIKE_CP
  pop_state GIT_COMMITTER_DATE
  pop_state GIT_AUTHOR_DATE
  pop_state GIT_COMMITTER_EMAIL
  pop_state GIT_COMMITTER_NAME
  pop_state GIT_AUTHOR_EMAIL
  pop_state GIT_AUTHOR_NAME

  return $result
}
