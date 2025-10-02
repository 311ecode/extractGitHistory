#!/usr/bin/env bash
test_extractGitPath_multipleCommits() {
    echo "Testing extraction preserves commit history"
    
    # Create test repo with multiple commits
    local test_repo=$(mktemp -d)
    cd "$test_repo"
    git init >/dev/null 2>&1
    git config user.name "Test" >/dev/null 2>&1
    git config user.email "test@test.com" >/dev/null 2>&1
    
    mkdir -p project/src
    echo "v1" > project/src/file.txt
    git add . >/dev/null 2>&1
    git commit -m "First commit" >/dev/null 2>&1
    
    echo "v2" > project/src/file.txt
    git add . >/dev/null 2>&1
    git commit -m "Second commit" >/dev/null 2>&1
    
    echo "v3" > project/src/file.txt
    git add . >/dev/null 2>&1
    git commit -m "Third commit" >/dev/null 2>&1
    
    # Extract path
    local stderr_capture=$(mktemp)
    local meta_file
    meta_file=$(extract_git_path "$test_repo/project/src" 2>"$stderr_capture")
    local exit_code=$?
    local repo_path=$(tail -1 "$stderr_capture")  # Get only last line
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
    
    # Check commit count
    cd "$repo_path" || {
      echo "ERROR: Cannot cd to repo_path: $repo_path"
      rm -rf "$(dirname "$meta_file")"
      return 1
    }
    local commit_count=$(git log --oneline | wc -l)
    
    if [[ $commit_count -ne 3 ]]; then
      echo "ERROR: Expected 3 commits, found $commit_count"
      cd - >/dev/null
      rm -rf "$(dirname "$meta_file")"
      return 1
    fi
    
    # Cleanup
    cd - >/dev/null
    rm -rf "$(dirname "$meta_file")"
    
    echo "SUCCESS: All commits preserved in extraction"
    return 0
  }