#!/usr/bin/env bash
test_argument_validation() {
    echo "🧪 Testing argument validation"
    local err_msg
    err_msg=$(extract_git_path 2>&1)
    if [[ "$err_msg" == *"Usage: extract_git_path <path>"* ]]; then
      echo "✅ SUCCESS: Caught missing arguments"
      return 0
    else
      echo "❌ ERROR: Failed to validate arguments"
      return 1
    fi
  }