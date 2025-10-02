#!/usr/bin/env bash
testRepoRoot() {
    echo "Testing extraction of entire repository (root path)"
    
    # Create test repo
    local test_repo=$(mktemp -d)
    cd "$test_repo"
    git init >/dev/null 2>&1
    git config user.name "Test" >/dev/null 2>&1
    git config user.email "test@test.com" >/dev/null 2>&1
    
    echo "root file" > file.txt
    mkdir subdir
    echo "nested" > subdir/nested.txt
    git add . >/dev/null 2>&1
    git commit -m "Initial commit" >/dev/null 2>&1
    
    # Extract entire repo
    local output=$(extract_git_path "$test_repo")
    local exit_code=$?
    
    # Cleanup test repo
    rm -rf "$test_repo"
    
    if [[ $exit_code -ne 0 ]]; then
      echo "ERROR: Function failed"
      rm -rf "$output" 2>/dev/null
      return 1
    fi
    
    # Verify structure preserved
    if [[ ! -f "$output/file.txt" ]] || [[ ! -f "$output/subdir/nested.txt" ]]; then
      echo "ERROR: Full repo structure not preserved"
      rm -rf "$output"
      return 1
    fi
    
    # Cleanup
    rm -rf "$output"
    
    echo "SUCCESS: Entire repo extraction works"
    return 0
  }