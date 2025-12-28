#!/usr/bin/env bash

testGitPathMove() {
  testDeepIntraRepoMove() {
    echo "🧪 Testing Deep Move (Creating nested parents)"
    local tmp_dir=$(mktemp -d)
    
    mkdir -p "$tmp_dir/repo/source_folder"
    cd "$tmp_dir/repo" && git init -q
    git config user.email "test@test.com"
    git config user.name "Tester"
    
    echo "important_data" > source_folder/data.txt
    git add . && git commit -m "feat: source" -q
    
    # Move to a non-existent nested path
    git_path_move "source_folder" "deep/nested/path/target_folder"
    
    # Verification
    if [[ ! -f "deep/nested/path/target_folder/data.txt" ]]; then
      echo "❌ ERROR: File not found in deeply nested destination!"
      return 1
    fi

    if [[ -d "source_folder" ]]; then
      echo "❌ ERROR: Source folder was not cleaned up!"
      return 1
    fi

    echo "✅ SUCCESS: Deep move created parent directories and preserved history."
    return 0
  }

  local test_functions=("testDeepIntraRepoMove")
  local ignored_tests=()
  bashTestRunner test_functions ignored_tests
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  testGitPathMove
fi
