#!/usr/bin/env bash

testGitPathMove() {
  testFullIntraRepoMove() {
    echo "🧪 Testing Full Intra-repo Move (A vanishes, B appears)"
    local tmp_dir=$(mktemp -d)
    
    mkdir -p "$tmp_dir/repo/dir_a"
    cd "$tmp_dir/repo" && git init -q
    git config user.email "test@test.com"
    git config user.name "Tester"
    
    echo "data" > dir_a/file.txt
    git add . && git commit -m "feat: initial data" -q
    
    # The actual move
    git_path_move "dir_a" "dir_b"
    
    # 1. A should be gone
    if [[ -d "dir_a" ]]; then
      echo "❌ ERROR: dir_a still exists!"
      return 1
    fi
    
    # 2. B should exist (because of the auto-merge)
    if [[ ! -f "dir_b/file.txt" ]]; then
      echo "❌ ERROR: dir_b/file.txt does not exist! Auto-merge failed?"
      return 1
    fi

    # 3. History should be linked
    local log_count=$(git log --oneline -- dir_b/file.txt | wc -l)
    if [[ $log_count -eq 0 ]]; then
      echo "❌ ERROR: History not preserved for dir_b"
      return 1
    fi

    echo "✅ SUCCESS: A moved to B seamlessly."
    return 0
  }

  local test_functions=("testFullIntraRepoMove")
  local ignored_tests=()
  bashTestRunner test_functions ignored_tests
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  testGitPathMove
fi
