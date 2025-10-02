#!/usr/bin/env bash
testHistoryFlattened() {
    echo "Testing that extracted history is flattened to root"
    
    # Create test repo with nested structure
    local test_repo=$(mktemp -d)
    cd "$test_repo"
    git init >/dev/null 2>&1
    git config user.name "Test" >/dev/null 2>&1
    git config user.email "test@test.com" >/dev/null 2>&1
    
    mkdir -p deep/nested/subproject
    echo "content" > deep/nested/subproject/file.txt
    git add . >/dev/null 2>&1
    git commit -m "Add nested file" >/dev/null 2>&1
    
    # Extract nested path
    local output=$(extract_git_path "$test_repo/deep/nested/subproject")
    local exit_code=$?
    
    # Cleanup test repo
    rm -rf "$test_repo"
    
    if [[ $exit_code -ne 0 ]]; then
      echo "ERROR: Function failed"
      rm -rf "$output" 2>/dev/null
      return 1
    fi
    
    # Check that file is at root in extracted repo
    if [[ ! -f "$output/file.txt" ]]; then
      echo "ERROR: File not flattened to root (expected file.txt at root)"
      rm -rf "$output"
      return 1
    fi
    
    if [[ -d "$output/deep" ]]; then
      echo "ERROR: Directory structure not flattened (deep/ still exists)"
      rm -rf "$output"
      return 1
    fi
    
    # Cleanup
    rm -rf "$output"
    
    echo "SUCCESS: History correctly flattened to root"
    return 0
  }