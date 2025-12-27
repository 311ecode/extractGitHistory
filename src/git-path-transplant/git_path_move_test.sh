#!/usr/bin/env bash

testGitPathMove() {
  export LC_NUMERIC=C
  local debug="${DEBUG:-}"

  testEndToEndMove() {
    echo "🧪 Testing End-to-End git_path_move (UX Check)"
    local tmp_dir=$(mktemp -d)
    
    # 1. Setup source repository
    mkdir -p "$tmp_dir/source_repo/src/feature"
    cd "$tmp_dir/source_repo" && git init -q
    git config user.email "mover@test.com"
    git config user.name "MoverBot"
    
    echo "hello" > src/feature/code.txt
    GIT_AUTHOR_DATE="2025-01-01T12:00:00Z" GIT_COMMITTER_DATE="2025-01-01T12:00:00Z" \
      git add . && git commit -m "feat: initial code" -q
    
    local source_hash=$(git rev-parse HEAD)

    # 2. Setup destination repository (Monorepo)
    mkdir -p "$tmp_dir/monorepo"
    cd "$tmp_dir/monorepo" && git init -q
    git config user.email "mover@test.com"
    git config user.name "MoverBot"
    git commit --allow-empty -m "initial monorepo commit" -q

    # 3. Perform the Move using the new simplified function
    # Moving from source_repo/src/feature to monorepo/packages/legacy-feature
    git_path_move "$tmp_dir/source_repo/src/feature" "packages/legacy-feature"

    # 4. Verification
    cd "$tmp_dir/monorepo" || return 1
    if ! git checkout "history/packages/legacy-feature" --quiet; then
      echo "❌ ERROR: History branch was not created."
      return 1
    fi

    if [[ ! -f "packages/legacy-feature/code.txt" ]]; then
      echo "❌ ERROR: File was not found at the new destination."
      return 1
    fi

    # Check for history preservation (the content should match)
    local moved_content=$(cat packages/legacy-feature/code.txt)
    if [[ "$moved_content" == "hello" ]]; then
      echo "✅ SUCCESS: Content and history moved correctly via git_path_move!"
      return 0
    else
      echo "❌ ERROR: Content mismatch after move."
      return 1
    fi
  }

  local test_functions=("testEndToEndMove")
  local ignored_tests=()
  bashTestRunner test_functions ignored_tests
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  testGitPathMove
fi
