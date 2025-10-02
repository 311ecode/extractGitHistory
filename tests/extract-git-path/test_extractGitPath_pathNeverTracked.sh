#!/usr/bin/env bash
test_extractGitPath_pathNeverTracked() {
    echo "Testing error when path never tracked"
    
    # Create test repo
    local test_repo=$(mktemp -d)
    cd "$test_repo"
    git init >/dev/null 2>&1
    git config user.name "Test" >/dev/null 2>&1
    git config user.email "test@test.com" >/dev/null 2>&1
    
    echo "content" > file.txt
    git add file.txt >/dev/null 2>&1
    git commit -m "Initial commit" >/dev/null 2>&1
    
    mkdir untracked_dir
    
    if [[ -n "${DEBUG:-}" ]]; then
      echo "DEBUG: Test repo: $test_repo" >&2
      echo "DEBUG: Untracked path: $test_repo/untracked_dir" >&2
    fi
    
    # Try to extract untracked path - capture exit code separately
    local output
    local exit_code
    output=$(extract_git_path "$test_repo/untracked_dir" 2>&1)
    exit_code=$?
    
    if [[ -n "${DEBUG:-}" ]]; then
      echo "DEBUG: Exit code: $exit_code" >&2
      echo "DEBUG: Output: $output" >&2
    fi
    
    rm -rf "$test_repo"
    
    if [[ $exit_code -eq 0 ]]; then
      echo "ERROR: Function should have failed for untracked path (exit code was 0)"
      return 1
    fi
    
    if ! echo "$output" | grep -q "no git history"; then
      echo "ERROR: Expected error message about no git history"
      echo "ERROR: Got: $output"
      return 1
    fi
    
    echo "SUCCESS: Correctly errors for untracked path"
    return 0
  }