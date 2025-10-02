#!/usr/bin/env bash
testRelativePath() {
    echo "Testing extraction with relative path"
    
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
    
    # Extract with relative path
    cd "$test_repo"
    local output=$(extract_git_path "src/subproject")
    local exit_code=$?
    
    # Cleanup test repo
    rm -rf "$test_repo"
    
    if [[ $exit_code -ne 0 ]]; then
      echo "ERROR: Function failed with exit code $exit_code"
      rm -rf "$output" 2>/dev/null
      return 1
    fi
    
    if [[ ! -d "$output" ]]; then
      echo "ERROR: Output directory does not exist"
      rm -rf "$output"
      return 1
    fi
    
    # Cleanup
    rm -rf "$output"
    
    echo "SUCCESS: Relative path extraction works"
    return 0
  }