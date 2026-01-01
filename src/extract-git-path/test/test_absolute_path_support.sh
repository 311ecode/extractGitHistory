#!/usr/bin/env bash
test_absolute_path_support() {
    echo "🧪 Testing absolute path support"
    local temp_repo
    temp_repo=$(mktemp -d)
    extract_git_path_test_setup_test_repo "$temp_repo"

    # Use a fixed absolute path
    local abs_target="$temp_repo/src"
    
    # Run from a completely unrelated directory (like /tmp)
    local meta_file
    meta_file=$(cd /tmp && extract_git_path "$abs_target")
    
    if [[ -f "$meta_file" ]]; then
      local extracted_path
      extracted_path=$(grep "original_path" "$meta_file" | cut -d'"' -f4)
      if [[ "$extracted_path" == "$abs_target" ]]; then
        echo "✅ SUCCESS: Absolute path resolved and stored correctly"
        rm -rf "$temp_repo"
        return 0
      fi
    fi

    echo "❌ ERROR: Absolute path resolution failed"
    rm -rf "$temp_repo"
    return 1
}
