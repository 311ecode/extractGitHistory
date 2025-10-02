#!/usr/bin/env bash
test_extractGitPath_pathNotInRepo() {
    echo "Testing error when path not in git repo"
    
    # Create temp dir in /tmp to avoid being in current git repo
    local temp_dir=$(mktemp -d -p /tmp)
    mkdir -p "$temp_dir/not-a-repo"
    
    local test_path="$temp_dir/not-a-repo"
    
    if [[ -n "${DEBUG:-}" ]]; then
      echo "DEBUG: Test temp dir: $temp_dir" >&2
      echo "DEBUG: Test path: $test_path" >&2
    fi
    
    # Capture stderr and exit code separately
    local output
    local exit_code
    output=$(extract_git_path "$test_path" 2>&1)
    exit_code=$?
    
    if [[ -n "${DEBUG:-}" ]]; then
      echo "DEBUG: Exit code: $exit_code" >&2
      echo "DEBUG: Output: $output" >&2
    fi
    
    rm -rf "$temp_dir"
    
    if [[ $exit_code -eq 0 ]]; then
      echo "ERROR: Function should have failed for non-repo path (exit code was 0)"
      return 1
    fi
    
    if ! echo "$output" | grep -q "not inside a git repository"; then
      echo "ERROR: Expected error message about not being in repo"
      echo "ERROR: Got: $output"
      return 1
    fi
    
    echo "SUCCESS: Correctly errors for non-repo path"
    return 0
  }