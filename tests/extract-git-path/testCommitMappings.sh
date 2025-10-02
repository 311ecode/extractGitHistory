#!/usr/bin/env bash
testCommitMappings() {
    echo "Testing commit hash mappings in extract-git-path-meta.json"
    
    # Create test repo with multiple commits
    local test_repo=$(mktemp -d)
    cd "$test_repo"
    git init >/dev/null 2>&1
    git config user.name "Test User" >/dev/null 2>&1
    git config user.email "test@example.com" >/dev/null 2>&1
    
    mkdir -p project/src
    echo "v1" > project/src/file.txt
    git add . >/dev/null 2>&1
    git commit -m "First commit" >/dev/null 2>&1
    local commit1=$(git rev-parse HEAD)
    
    echo "v2" > project/src/file.txt
    git add . >/dev/null 2>&1
    git commit -m "Second commit" >/dev/null 2>&1
    local commit2=$(git rev-parse HEAD)
    
    echo "v3" > project/src/file.txt
    git add . >/dev/null 2>&1
    git commit -m "Third commit" >/dev/null 2>&1
    local commit3=$(git rev-parse HEAD)
    
    if [[ -n "${DEBUG:-}" ]]; then
      echo "DEBUG: Original commits:" >&2
      echo "DEBUG:   commit1 = $commit1" >&2
      echo "DEBUG:   commit2 = $commit2" >&2
      echo "DEBUG:   commit3 = $commit3" >&2
      echo "DEBUG: Checking git log in test repo:" >&2
      git log --reverse --pretty=format:'%H|%s' -- project/src >&2
      echo "" >&2
    fi
    
    # Extract path - handle stderr differently based on DEBUG
    local stderr_capture=$(mktemp)
    local meta_file
    
    if [[ -n "${DEBUG:-}" ]]; then
      # In DEBUG mode, let stderr flow through and capture it
      meta_file=$(extract_git_path "$test_repo/project/src" 2> >(tee "$stderr_capture" >&2))
      local exit_code=$?
      local repo_path=$(tail -1 "$stderr_capture")
    else
      meta_file=$(extract_git_path "$test_repo/project/src" 2>"$stderr_capture")
      local exit_code=$?
      local repo_path=$(tail -1 "$stderr_capture")
    fi
    
    rm -f "$stderr_capture"
    
    # Cleanup test repo
    rm -rf "$test_repo"
    
    if [[ $exit_code -ne 0 ]]; then
      echo "ERROR: Function failed"
      [[ -n "$meta_file" ]] && rm -rf "$(dirname "$meta_file")" 2>/dev/null
      return 1
    fi
    
    # Verify filename is extract-git-path-meta.json
    if [[ "$(basename "$meta_file")" != "extract-git-path-meta.json" ]]; then
      echo "ERROR: Expected extract-git-path-meta.json, got: $(basename "$meta_file")"
      rm -rf "$(dirname "$meta_file")"
      return 1
    fi
    
    if [[ -n "${DEBUG:-}" ]]; then
      echo "DEBUG: extract-git-path-meta.json contents:" >&2
      cat "$meta_file" >&2
      echo "" >&2
      echo "DEBUG: Checking for commits in extract-git-path-meta.json:" >&2
    fi
    
    # Verify extract-git-path-meta.json has commit_mappings
    if ! grep -q '"commit_mappings"' "$meta_file"; then
      echo "ERROR: extract-git-path-meta.json missing commit_mappings"
      rm -rf "$(dirname "$meta_file")"
      return 1
    fi
    
    # Check that all three original commits are mapped
    if ! grep -q "\"$commit1\"" "$meta_file"; then
      echo "ERROR: First commit not in mappings"
      [[ -n "${DEBUG:-}" ]] && echo "DEBUG: Looking for: $commit1" >&2
      rm -rf "$(dirname "$meta_file")"
      return 1
    fi
    
    if [[ -n "${DEBUG:-}" ]]; then
      echo "DEBUG: Found commit1: $commit1" >&2
    fi
    
    if ! grep -q "\"$commit2\"" "$meta_file"; then
      echo "ERROR: Second commit not in mappings"
      [[ -n "${DEBUG:-}" ]] && echo "DEBUG: Looking for: $commit2" >&2
      rm -rf "$(dirname "$meta_file")"
      return 1
    fi
    
    if [[ -n "${DEBUG:-}" ]]; then
      echo "DEBUG: Found commit2: $commit2" >&2
    fi
    
    if ! grep -q "\"$commit3\"" "$meta_file"; then
      echo "ERROR: Third commit not in mappings"
      [[ -n "${DEBUG:-}" ]] && echo "DEBUG: Looking for: $commit3" >&2
      [[ -n "${DEBUG:-}" ]] && echo "DEBUG: Grep result for commit3:" >&2
      [[ -n "${DEBUG:-}" ]] && grep "$commit3" "$meta_file" >&2 || echo "DEBUG: No match found" >&2
      rm -rf "$(dirname "$meta_file")"
      return 1
    fi
    
    if [[ -n "${DEBUG:-}" ]]; then
      echo "DEBUG: Found commit3: $commit3" >&2
    fi
    
    # Cleanup
    rm -rf "$(dirname "$meta_file")"
    
    echo "SUCCESS: Commit mappings correctly generated in extract-git-path-meta.json"
    return 0
  }