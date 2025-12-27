#!/usr/bin/env bash

testGitPathMove() {
  export LC_NUMERIC=C
  local debug="${DEBUG:-}"

  testIntraRepoMoveCleanup() {
    echo "🧪 Testing Intra-repo move (Source should be deleted)"
    local tmp_dir=$(mktemp -d)
    
    # Setup single repo
    mkdir -p "$tmp_dir/repo/old_dir"
    cd "$tmp_dir/repo" && git init -q
    git config user.email "mover@test.com"
    git config user.name "MoverBot"
    
    echo "content" > old_dir/file.txt
    git add . && git commit -m "feat: original location" -q
    
    # Move within the same repo
    git_path_move "old_dir" "new_dir"
    
    # Verification
    if [[ -d "old_dir" ]]; then
      echo "❌ ERROR: Source directory 'old_dir' should have been deleted (Intra-repo)!"
      return 1
    fi
    echo "✅ SUCCESS: Intra-repo source deleted."
    return 0
  }

  testInterRepoMoveSafety() {
    echo "🧪 Testing Inter-repo move (Source should NOT be deleted)"
    local tmp_dir=$(mktemp -d)
    
    # 1. Setup Source Repo
    mkdir -p "$tmp_dir/source_repo/shared_utils"
    cd "$tmp_dir/source_repo" && git init -q
    git config user.email "mover@test.com"
    git config user.name "MoverBot"
    echo "utility-code" > shared_utils/lib.sh
    git add . && git commit -m "feat: shared utils" -q

    # 2. Setup Destination Repo
    mkdir -p "$tmp_dir/dest_repo"
    cd "$tmp_dir/dest_repo" && git init -q
    git config user.email "mover@test.com"
    git config user.name "MoverBot"
    git commit --allow-empty -m "init dest" -q

    # 3. Move from source_repo to dest_repo
    git_path_move "$tmp_dir/source_repo/shared_utils" "imported_utils"

    # 4. Verification
    if [[ ! -d "$tmp_dir/source_repo/shared_utils" ]]; then
      echo "❌ ERROR: Source directory was deleted in an INTER-repo move! This is unsafe."
      return 1
    fi
    
    # Verify the branch exists in destination
    cd "$tmp_dir/dest_repo"
    if ! git rev-parse --verify "history/imported_utils" >/dev/null 2>&1; then
      echo "❌ ERROR: History branch not found in destination repo."
      return 1
    fi

    echo "✅ SUCCESS: Inter-repo source preserved."
    return 0
  }

  local test_functions=("testIntraRepoMoveCleanup" "testInterRepoMoveSafety")
  local ignored_tests=()
  bashTestRunner test_functions ignored_tests
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  testGitPathMove
fi
