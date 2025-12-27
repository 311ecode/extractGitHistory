#!/usr/bin/env bash

testGitPathTransplant() {
  export LC_NUMERIC=C
  local debug="${DEBUG:-}"

  testHashParityRoundTrip() {
    echo "🧪 Testing Hash Parity (Deterministic ID Check)"
    local tmp_dir=$(mktemp -d)
    
    # 1. Create Source with strict timestamps
    mkdir -p "$tmp_dir/orig" && cd "$tmp_dir/orig" && git init -q
    git config user.email "parity@test.com"
    git config user.name "ParityBot"
    echo "content" > file.txt
    GIT_AUTHOR_DATE="2025-01-01T12:00:00" GIT_COMMITTER_DATE="2025-01-01T12:00:00" \
      git add file.txt && git commit -m "fix: logic" -q
    local orig_hash=$(git rev-parse HEAD)

    # 2. Extract
    local meta=$(extract_git_path "$tmp_dir/orig/file.txt" 2>/dev/null)
    
    # 3. Monorepo Transplant
    mkdir -p "$tmp_dir/monorepo" && cd "$tmp_dir/monorepo" && git init -q
    git commit --allow-empty -m "root" -q
    
    git_path_transplant "$meta" "moved/here"
    
    # 4. Switch to the grafted branch to verify
    git checkout "history/moved/here" --quiet
    
    # 5. Re-Extract
    # We must pass the absolute path to the directory inside the monorepo
    local second_meta=$(extract_git_path "$tmp_dir/monorepo/moved/here" 2>/dev/null)
    local final_repo=$(jq -r '.extracted_repo_path' "$second_meta")
    
    cd "$final_repo"
    local final_hash=$(git rev-parse HEAD)
    
    [[ -n "$debug" ]] && echo "DEBUG: Source: $orig_hash"
    [[ -n "$debug" ]] && echo "DEBUG: Final:  $final_hash"

    if [[ "$orig_hash" == "$final_hash" ]]; then
      echo "✅ SUCCESS: Hash parity maintained!"
      return 0
    else
      echo "❌ ERROR: Hash mismatch!"
      return 1
    fi
  }

  local test_functions=("testHashParityRoundTrip")
  local ignored_tests=()
  bashTestRunner test_functions ignored_tests
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  testGitPathTransplant
fi
