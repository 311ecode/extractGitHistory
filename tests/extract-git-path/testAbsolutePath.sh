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
    
    # Extract - capture both outputs separately
    local stderr_capture=$(mktemp)
    local meta_file
    meta_file=$(extract_git_path "$test_repo/src/subproject" 2>"$stderr_capture")
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
    
    if [[ ! -f "$meta_file" ]]; then
      echo "ERROR: extract-git-path-meta.json does not exist: $meta_file"
      return 1
    fi
    
    # Verify it's the correct filename
    if [[ "$(basename "$meta_file")" != "extract-git-path-meta.json" ]]; then
      echo "ERROR: Expected extract-git-path-meta.json, got: $(basename "$meta_file")"
      rm -rf "$(dirname "$meta_file")"
      return 1
    fi
    
    if [[ ! -d "$repo_path" ]]; then
      echo "ERROR: Repo directory does not exist: $repo_path"
      rm -rf "$(dirname "$meta_file")"
      return 1
    fi
    
    # Verify it's a git repo
    if [[ ! -d "$repo_path/.git" ]]; then
      echo "ERROR: Output is not a git repository"
      rm -rf "$(dirname "$meta_file")"
      return 1
    fi
    
    # Verify meta.json structure
    if ! grep -q '"original_path"' "$meta_file"; then
      echo "ERROR: extract-git-path-meta.json missing original_path"
      rm -rf "$(dirname "$meta_file")"
      return 1
    fi
    
    # Cleanup
    rm -rf "$(dirname "$meta_file")"
    
    echo "SUCCESS: Absolute path extraction works"
    return 0
  }