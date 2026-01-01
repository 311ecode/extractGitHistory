#!/usr/bin/env bash
test_outside_git_repo() {
    echo "🧪 Testing execution outside of a git repository"
    local tmp_dir
    tmp_dir=$(mktemp -d)
    
    # Run in a non-git directory
    local err_msg
    err_msg=$(cd "$tmp_dir" && extract_git_path "$tmp_dir" 2>&1)
    
    rm -rf "$tmp_dir"
    
    if [[ "$err_msg" == *"not inside a git repository"* ]]; then
      echo "✅ SUCCESS: Correctly identified non-repo path"
      return 0
    else
      echo "❌ ERROR: Failed to detect non-git directory"
      return 1
    fi
  }