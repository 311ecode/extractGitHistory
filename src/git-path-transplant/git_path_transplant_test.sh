#!/usr/bin/env bash

testGitPathTransplant() {
  export LC_NUMERIC=C
  local debug="${DEBUG:-}"

  testHashParityRoundTrip() {
    echo "🧪 Testing Hash Parity (Deterministic ID Check)"
    local tmp_dir=$(mktemp -d)
    
    # 1. Create Source with strict timestamps for determinism
    mkdir -p "$tmp_dir/orig" && cd "$tmp_dir/orig" && git init -q
    git config user.email "parity@test.com"
    git config user.name "ParityBot"
    echo "content" > file.txt
    GIT_AUTHOR_DATE="2025-01-01T12:00:00Z" GIT_COMMITTER_DATE="2025-01-01T12:00:00Z" \
      git add file.txt && git commit -m "fix: logic" -q
    local orig_hash=$(git rev-parse HEAD)
    [[ -n "$debug" ]] && echo "🧪 DEBUG: Source Hash: $orig_hash" >&2

    # 2. Extract folder history
    local meta
    meta=$(extract_git_path "$tmp_dir/orig/file.txt" 2>/dev/null)
    if [[ ! -f "$meta" ]]; then
      echo "❌ ERROR: Initial extraction failed to create meta file"
      return 1
    fi

    # 3. Monorepo Transplant
    local monorepo_root="$tmp_dir/monorepo"
    mkdir -p "$monorepo_root" && cd "$monorepo_root" && git init -q
    git config user.email "parity@test.com"
    git config user.name "ParityBot"
    git commit --allow-empty -m "root" -q
    
    # Transplant history into "moved/here"
    git_path_transplant "$meta" "moved/here"
    
    # 4. Switch to the grafted branch to verify
    # We must ensure we are on the branch where the transformed history lives
    if ! git checkout "history/moved/here" --quiet; then
      echo "❌ ERROR: Failed to checkout history/moved/here"
      return 1
    fi
    
    # Verify the file actually exists in the expected location
    if [[ ! -f "moved/here/file.txt" ]]; then
      echo "❌ ERROR: File not found at expected transplanted path: moved/here/file.txt"
      [[ -n "$debug" ]] && ls -R >&2
      return 1
    fi
    
    # 5. Re-Extract from Monorepo (Deterministic Check)
    # We pass the absolute path to the directory inside the monorepo
    local second_meta
    second_meta=$(extract_git_path "$monorepo_root/moved/here" 2>/dev/null)
    
    if [[ ! -f "$second_meta" ]]; then
      echo "❌ ERROR: Re-extraction failed to produce meta file"
      return 1
    fi

    local final_repo
    final_repo=$(jq -r '.extracted_repo_path // empty' "$second_meta")
    
    if [[ -z "$final_repo" ]]; then
      echo "❌ ERROR: Could not parse extracted_repo_path from $second_meta"
      [[ -n "$debug" ]] && cat "$second_meta" >&2
      return 1
    fi
    
    cd "$final_repo" || return 1
    local final_hash=$(git rev-parse HEAD)
    
    echo "📊 Hash Comparison:"
    echo "   Source: $orig_hash"
    echo "   Final:  $final_hash"

    if [[ "$orig_hash" == "$final_hash" ]]; then
      echo "✅ SUCCESS: Hash parity maintained!"
      return 0
    else
      echo "❌ ERROR: Hash mismatch!"
      if [[ -n "$debug" ]]; then
        echo "--- Original Commit Details ---" >&2
        cd "$tmp_dir/orig" && git show --format=fuller -s HEAD >&2
        echo "--- Final Commit Details ---" >&2
        cd "$final_repo" && git show --format=fuller -s HEAD >&2
      fi
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
