#!/usr/bin/env bash

testComplexHistoryPreservation() {
  echo "🧪 Testing Complex History Preservation (merge vs rebase extraction parity)"
  
  # Protect environment
  push_state GIT_PATH_TRANSPLANT_ACT_LIKE_CP "0"
  push_state GIT_PATH_TRANSPLANT_USE_CLEANSE "0"
  push_state GIT_PATH_TRANSPLANT_USE_REBASE "0"
  push_state DEBUG "1"
  push_state PWD

  local tmp_dir=$(mktemp -d)
  local result=0

  (
    cd "$tmp_dir" || exit 1
    
    # ═══════════════════════════════════════════════════════════
    # REPO A: History via MERGE
    # ═══════════════════════════════════════════════════════════
    mkdir repo_merge && cd repo_merge
    git init -q
    git config user.email "complex@test.com"
    git config user.name "Complex History Tester"

    mkdir -p src/feature utils
    echo "main code" > src/main.py
    echo "helper" > utils/helper.sh
    git add . && git commit -m "feat: initial structure" -q

    git checkout -b feature-branch
    echo "v1" >> src/main.py
    git add src/main.py && git commit -m "feat: version 1" -q
    echo "v2" >> src/main.py
    git mv src/main.py src/feature/main.py
    git commit -m "refactor: move main to feature dir" -q

    git checkout main
    git checkout -b utils-branch
    echo "better helper" >> utils/helper.sh
    git add utils/helper.sh && git commit -m "feat: better helper" -q

    git checkout main
    git merge feature-branch --no-edit -q >/dev/null 2>&1
    git merge utils-branch --no-edit -q >/dev/null 2>&1

    echo "# README" > README.md
    git add README.md && git commit -m "docs: add readme" -q

    # ═══════════════════════════════════════════════════════════
    # REPO B: Same history via REBASE
    # ═══════════════════════════════════════════════════════════
    cd "$tmp_dir"
    mkdir repo_rebase && cd repo_rebase
    git init -q
    git config user.email "complex@test.com"
    git config user.name "Complex History Tester"

    mkdir -p src/feature utils
    echo "main code" > src/main.py
    echo "helper" > utils/helper.sh
    git add . && git commit -m "feat: initial structure" -q

    # Build feature changes linearly
    echo "v1" >> src/main.py
    git add src/main.py && git commit -m "feat: version 1" -q
    echo "v2" >> src/main.py
    git mv src/main.py src/feature/main.py
    git commit -m "refactor: move main to feature dir" -q

    # Add utils change linearly
    echo "better helper" >> utils/helper.sh
    git add utils/helper.sh && git commit -m "feat: better helper" -q

    echo "# README" > README.md
    git add README.md && git commit -m "docs: add readme" -q

    # ═══════════════════════════════════════════════════════════
    # EXTRACT both repos' src/ paths
    # ═══════════════════════════════════════════════════════════
    echo ""
    echo "📦 Extracting from MERGE-based repo..."
    local meta_merge
    meta_merge=$(extract_git_path "$tmp_dir/repo_merge/src") || exit 1
    local extracted_merge=$(jq -r '.extracted_repo_path' "$meta_merge")

    echo "📦 Extracting from REBASE-based repo..."
    local meta_rebase
    meta_rebase=$(extract_git_path "$tmp_dir/repo_rebase/src") || exit 1
    local extracted_rebase=$(jq -r '.extracted_repo_path' "$meta_rebase")

    # ═══════════════════════════════════════════════════════════
    # COMPARE: Tree structure and commit content
    # ═══════════════════════════════════════════════════════════
    echo ""
    echo "🔍 Comparing extracted repositories..."

    # Compare commit count
    local count_merge=$(cd "$extracted_merge" && git rev-list --count HEAD)
    local count_rebase=$(cd "$extracted_rebase" && git rev-list --count HEAD)
    
    if [[ "$count_merge" -ne "$count_rebase" ]]; then
      echo "❌ ERROR: Commit count mismatch (merge: $count_merge, rebase: $count_rebase)"
      exit 1
    fi
    echo "✅ Commit count match: $count_merge commits"

    # Compare final tree hash (most important: is the content identical?)
    local tree_merge=$(cd "$extracted_merge" && git rev-parse HEAD^{tree})
    local tree_rebase=$(cd "$extracted_rebase" && git rev-parse HEAD^{tree})
    
    if [[ "$tree_merge" != "$tree_rebase" ]]; then
      echo "❌ ERROR: Final tree hash mismatch!"
      echo "   Merge tree:  $tree_merge"
      echo "   Rebase tree: $tree_rebase"
      exit 1
    fi
    echo "✅ Final tree hash match: $tree_merge"

    # Compare commit messages (order-independent)
    local msgs_merge=$(cd "$extracted_merge" && git log --format=%s --no-merges | sort)
    local msgs_rebase=$(cd "$extracted_rebase" && git log --format=%s --no-merges | sort)
    
    if [[ "$msgs_merge" != "$msgs_rebase" ]]; then
      echo "❌ ERROR: Commit messages differ!"
      echo "--- Merge repo ---"
      echo "$msgs_merge"
      echo "--- Rebase repo ---"
      echo "$msgs_rebase"
      exit 1
    fi
    echo "✅ Commit messages match (order-independent)"

    # Compare file structure
    local files_merge=$(cd "$extracted_merge" && git ls-tree -r HEAD --name-only | sort)
    local files_rebase=$(cd "$extracted_rebase" && git ls-tree -r HEAD --name-only | sort)
    
    if [[ "$files_merge" != "$files_rebase" ]]; then
      echo "❌ ERROR: File structure differs!"
      exit 1
    fi
    echo "✅ File structure match"

    # ═══════════════════════════════════════════════════════════
    # SUCCESS
    # ═══════════════════════════════════════════════════════════
    echo ""
    echo "ℹ️  Note: git-filter-repo --path extraction is deterministic."
    echo "       Merge commits are discarded, leaving only commits that touched the path."
    echo "       This ensures extracted repos are identical regardless of original topology."
    echo ""
    echo "✅ SUCCESS: Merge-based and rebase-based extractions are IDENTICAL."
    exit 0
  )

  result=$?
  rm -rf "$tmp_dir"

  pop_state PWD
  pop_state DEBUG
  pop_state GIT_PATH_TRANSPLANT_USE_REBASE
  pop_state GIT_PATH_TRANSPLANT_USE_CLEANSE
  pop_state GIT_PATH_TRANSPLANT_ACT_LIKE_CP

  return $result
}
