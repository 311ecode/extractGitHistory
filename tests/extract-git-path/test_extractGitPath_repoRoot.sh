#!/usr/bin/env bash
test_extractGitPath_repoRoot() {
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
    local stderr_capture=$(mktemp)
    local meta_file
    meta_file=$(extract_git_path "$test_repo" 2>"$stderr_capture")
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
    
    # Verify structure preserved
    if [[ ! -f "$repo_path/file.txt" ]] || [[ ! -f "$repo_path/subdir/nested.txt" ]]; then
      echo "ERROR: Full repo structure not preserved"
      rm -rf "$(dirname "$meta_file")"
      return 1
    fi
    
    # Cleanup
    rm -rf "$(dirname "$meta_file")"
    
    echo "SUCCESS: Entire repo extraction works"
    return 0
  }