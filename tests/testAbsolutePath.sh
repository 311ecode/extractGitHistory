#!/usr/bin/env bash
testAbsolutePath() {
    echo "Testing extraction with absolute path"
    
    # Create test repo
    local test_repo=$(mktemp -d)
    cd "$test_repo"
    git init >/dev/null 2>&1
    git config user.name "Test" >/dev/null 2>&1
    git config user.email "test@test.com" >/dev/null 2>&1
    
    mkdir -p src/subproject
    echo "content" > src/subproject/file.txt
    git add . >/dev/null 2>&1
    git commit -m "Initial commit" >/dev/null 2>&1
    
    # Extract with absolute path
    local output=$(extract_git_path "$test_repo/src/subproject")
    local exit_code=$?
    
    # Cleanup test repo
    rm -rf "$test_repo"
    
    if [[ $exit_code -ne 0 ]]; then
      echo "ERROR: Function failed with exit code $exit_code"
      rm -rf "$output" 2>/dev/null
      return 1
    fi
    
    if [[ ! -d "$output" ]]; then
      echo "ERROR: Output directory does not exist: $output"
      return 1
    fi
    
    # Verify it's a git repo
    if [[ ! -d "$output/.git" ]]; then
      echo "ERROR: Output is not a git repository"
      rm -rf "$output"
      return 1
    fi
    
    # Cleanup
    rm -rf "$output"
    
    echo "SUCCESS: Absolute path extraction works"
    return 0
  }