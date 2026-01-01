#!/usr/bin/env bash
test_relative_parent_paths() {
    echo "🧪 Testing relative parent paths (../../style)"
    local temp_workspace
    temp_workspace=$(mktemp -d)
    
    # Setup repo in a subfolder
    local repo_dir="$temp_workspace/project/repo"
    extract_git_path_test_setup_test_repo "$repo_dir"
    
    # Create an external directory to run the command from
    local external_dir="$temp_workspace/other/work"
    mkdir -p "$external_dir"
    
    # Run extraction using a relative path that goes up and over
    # From: $temp_workspace/other/work
    # To:   ../../project/repo/src
    local meta_file
    meta_file=$(cd "$external_dir" && extract_git_path "../../project/repo/src")
    
    if [[ -f "$meta_file" ]]; then
      echo "✅ SUCCESS: Successfully resolved and extracted via parent relative path"
      rm -rf "$temp_workspace"
      return 0
    else
      echo "❌ ERROR: Failed to resolve parent relative path"
      rm -rf "$temp_workspace"
      return 1
    fi
}
