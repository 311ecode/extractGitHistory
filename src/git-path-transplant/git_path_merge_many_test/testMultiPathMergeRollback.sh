#!/usr/bin/env bash

testMultiPathMergeRollback() {
  echo "🧪 Testing Multi-Path Merge Rollback (atomic failure handling)"
  
  push_state DEBUG "1"
  push_state PWD

  local tmp_dir=$(mktemp -d)
  local result=0

  (
    cd "$tmp_dir" || exit 1

    # ═══════════════════════════════════════════════════════════
    # Setup: Create 2 valid source repos + 1 invalid path
    # ═══════════════════════════════════════════════════════════
    
    mkdir repoA && cd repoA
    git init -q
    git config user.email "test@test.com"
    git config user.name "Tester"
    mkdir -p src/moduleA
    echo "code A" > src/moduleA/file.js
    git add . && git commit -m "feat: module A" -q
    
    cd "$tmp_dir"
    mkdir repoB && cd repoB
    git init -q
    git config user.email "test@test.com"
    git config user.name "Tester"
    mkdir -p src/moduleB
    echo "code B" > src/moduleB/file.js
    git add . && git commit -m "feat: module B" -q

    # ═══════════════════════════════════════════════════════════
    # Setup: Destination monorepo with existing conflict
    # ═══════════════════════════════════════════════════════════
    cd "$tmp_dir"
    mkdir monorepo && cd monorepo
    git init -q
    git config user.email "test@test.com"
    git config user.name "Tester"
    
    echo "# Monorepo" > README.md
    git add . && git commit -m "init: monorepo" -q
    
    # Create a directory that will conflict with one of the transplants
    mkdir -p vendor/moduleB
    echo "existing code" > vendor/moduleB/existing.js
    git add . && git commit -m "feat: existing moduleB" -q
    
    local commit_before=$(git rev-parse HEAD)

    # ═══════════════════════════════════════════════════════════
    # Execute: Multi-path merge that SHOULD fail
    # ═══════════════════════════════════════════════════════════
    echo ""
    echo "🚀 Attempting merge with conflicting destination..."
    
    # This should fail because vendor/moduleB already exists
    git_path_merge_many \
      "$tmp_dir/repoA/src/moduleA:vendor/moduleA" \
      "$tmp_dir/repoB/src/moduleB:vendor/moduleB" \
      2>/dev/null
    
    local merge_status=$?

    # ═══════════════════════════════════════════════════════════
    # Verify: Operation failed as expected
    # ═══════════════════════════════════════════════════════════
    if [[ $merge_status -eq 0 ]]; then
      echo "❌ ERROR: Merge should have failed but succeeded!"
      exit 1
    fi
    echo "✅ Merge correctly failed"

    # ═══════════════════════════════════════════════════════════
    # Verify: Repository rolled back to original state
    # ═══════════════════════════════════════════════════════════
    echo ""
    echo "🔍 Verifying rollback..."
    
    local commit_after=$(git rev-parse HEAD)
    if [[ "$commit_before" != "$commit_after" ]]; then
      echo "❌ ERROR: Repository not rolled back to original commit!"
      echo "   Before: $commit_before"
      echo "   After:  $commit_after"
      exit 1
    fi
    echo "✅ Repository at original commit"

    # Verify vendor/moduleA was NOT created (rollback successful)
    if [[ -d "vendor/moduleA" ]]; then
      echo "❌ ERROR: Partial transplant not rolled back (vendor/moduleA exists)"
      exit 1
    fi
    echo "✅ No partial changes remain"

    # Verify original moduleB still exists
    if [[ ! -f "vendor/moduleB/existing.js" ]]; then
      echo "❌ ERROR: Original files were modified during rollback!"
      exit 1
    fi
    echo "✅ Original files intact"

    # Verify no leftover branches
    if git branch | grep -q "savepoint/merge-many"; then
      echo "❌ ERROR: Savepoint branch not cleaned up"
      exit 1
    fi
    echo "✅ No leftover branches"

    # ═══════════════════════════════════════════════════════════
    # SUCCESS
    # ═══════════════════════════════════════════════════════════
    echo ""
    echo "✅ SUCCESS: Atomic rollback verified!"
    echo "   - Operation failed as expected"
    echo "   - Repository rolled back to original state"
    echo "   - No partial changes remain"
    echo "   - Original files intact"
    exit 0
  )

  result=$?
  rm -rf "$tmp_dir"

  pop_state PWD
  pop_state DEBUG

  return $result
}
