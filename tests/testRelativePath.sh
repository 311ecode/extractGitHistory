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
    local stderr_capture=$(mktemp)
    local meta_file
    meta_file=$(extract_git_path "src/subproject" 2>"$stderr_capture")
    local exit_code=$?
    local repo_path=$(tail -1 "$stderr_capture")  # Get only last line
    rm -f "$stderr_capture"
    
    # Cleanup test repo
    rm -rf "$test_repo"
    
    if [[ $exit_code -ne 0 ]]; then
      echo "ERROR: Function failed with exit code $exit_code"
      [[ -n "$meta_file" ]] && rm -rf "$(dirname "$meta_file")" 2>/dev/null
      return 1
    fi
    
    if [[ ! -d "$repo_path" ]]; then
      echo "ERROR: Output directory does not exist: $repo_path"
      rm -rf "$(dirname "$meta_file")"
      return 1
    fi
    
    # Cleanup
    rm -rf "$(dirname "$meta_file")"
    
    echo "SUCCESS: Relative path extraction works"
    return 0
  }