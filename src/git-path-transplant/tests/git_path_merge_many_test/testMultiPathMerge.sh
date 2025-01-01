#!/usr/bin/env bash

testMultiPathMerge() {
  echo "🧪 Testing Multi-Path Merge (N sources → 1 destination repo)"
  
  push_state DEBUG "1"
  push_state PWD

  local tmp_dir=$(mktemp -d)
  local result=0

  (
    cd "$tmp_dir" || exit 1

    # ═══════════════════════════════════════════════════════════
    # Setup: Create 3 separate source repositories
    # ═══════════════════════════════════════════════════════════
    
    # Source Repo A: Authentication module
    mkdir repoA && cd repoA
    git init -q
    git config user.email "test@test.com"
    git config user.name "Tester"
    
    mkdir -p src/auth
    echo "login logic" > src/auth/login.js
    git add . && git commit -m "feat: add login" -q
    echo "logout logic" > src/auth/logout.js
    git add . && git commit -m "feat: add logout" -q
    
    # Source Repo B: Payment module
    cd "$tmp_dir"
    mkdir repoB && cd repoB
    git init -q
    git config user.email "test@test.com"
    git config user.name "Tester"
    
    mkdir -p src/payments
    echo "stripe integration" > src/payments/stripe.js
    git add . && git commit -m "feat: stripe payment" -q
    echo "paypal integration" > src/payments/paypal.js
    git add . && git commit -m "feat: paypal payment" -q
    
    # Source Repo C: Analytics module
    cd "$tmp_dir"
    mkdir repoC && cd repoC
    git init -q
    git config user.email "test@test.com"
    git config user.name "Tester"
    
    mkdir -p src/analytics
    echo "tracking code" > src/analytics/tracker.js
    git add . && git commit -m "feat: analytics tracking" -q
    
    # ═══════════════════════════════════════════════════════════
    # Setup: Create destination monorepo
    # ═══════════════════════════════════════════════════════════
    cd "$tmp_dir"
    mkdir monorepo && cd monorepo
    git init -q
    git config user.email "test@test.com"
    git config user.name "Tester"
    
    echo "# Monorepo" > README.md
    git add . && git commit -m "init: monorepo" -q

    # ═══════════════════════════════════════════════════════════
    # Execute: Multi-path merge
    # ═══════════════════════════════════════════════════════════
    echo ""
    echo "🚀 Executing multi-path merge..."
    
    git_path_merge_many \
      "$tmp_dir/repoA/src/auth:modules/auth" \
      "$tmp_dir/repoB/src/payments:modules/payments" \
      "$tmp_dir/repoC/src/analytics:modules/analytics"
    
    local merge_status=$?
    if [[ $merge_status -ne 0 ]]; then
      echo "❌ ERROR: git_path_merge_many failed"
      exit 1
    fi

    # ═══════════════════════════════════════════════════════════
    # Verify: All files present
    # ═══════════════════════════════════════════════════════════
    echo ""
    echo "🔍 Verifying file structure..."
    
    if [[ ! -f "modules/auth/login.js" ]] || [[ ! -f "modules/auth/logout.js" ]]; then
      echo "❌ ERROR: Auth module files missing"
      exit 1
    fi
    
    if [[ ! -f "modules/payments/stripe.js" ]] || [[ ! -f "modules/payments/paypal.js" ]]; then
      echo "❌ ERROR: Payment module files missing"
      exit 1
    fi
    
    if [[ ! -f "modules/analytics/tracker.js" ]]; then
      echo "❌ ERROR: Analytics module files missing"
      exit 1
    fi
    
    echo "✅ All files present"

    # ═══════════════════════════════════════════════════════════
    # Verify: History preserved for each module
    # ═══════════════════════════════════════════════════════════
    echo ""
    echo "🔍 Verifying history preservation..."
    
    local auth_commits=$(git log --oneline -- modules/auth | wc -l)
    if [[ $auth_commits -lt 2 ]]; then
      echo "❌ ERROR: Auth module history incomplete (expected 2+, got $auth_commits)"
      exit 1
    fi
    
    local payment_commits=$(git log --oneline -- modules/payments | wc -l)
    if [[ $payment_commits -lt 2 ]]; then
      echo "❌ ERROR: Payment module history incomplete (expected 2+, got $payment_commits)"
      exit 1
    fi
    
    local analytics_commits=$(git log --oneline -- modules/analytics | wc -l)
    if [[ $analytics_commits -lt 1 ]]; then
      echo "❌ ERROR: Analytics module history incomplete (expected 1+, got $analytics_commits)"
      exit 1
    fi
    
    echo "✅ History preserved (auth: $auth_commits, payments: $payment_commits, analytics: $analytics_commits)"

    # ═══════════════════════════════════════════════════════════
    # Verify: Commit messages preserved
    # ═══════════════════════════════════════════════════════════
    echo ""
    echo "🔍 Verifying commit messages..."
    
    if ! git log --all --format=%s | grep -q "feat: add login"; then
      echo "❌ ERROR: Auth commit message missing"
      exit 1
    fi
    
    if ! git log --all --format=%s | grep -q "feat: stripe payment"; then
      echo "❌ ERROR: Payment commit message missing"
      exit 1
    fi
    
    if ! git log --all --format=%s | grep -q "feat: analytics tracking"; then
      echo "❌ ERROR: Analytics commit message missing"
      exit 1
    fi
    
    echo "✅ All commit messages preserved"

    # ═══════════════════════════════════════════════════════════
    # Verify: Annotation commit created
    # ═══════════════════════════════════════════════════════════
    echo ""
    echo "🔍 Verifying annotation commit..."
    
    local last_commit_msg=$(git log -1 --format=%s)
    if [[ "$last_commit_msg" != "docs: multi-path history transplant completed" ]]; then
      echo "❌ ERROR: Expected annotation commit not found"
      echo "   Got: $last_commit_msg"
      exit 1
    fi
    
    # Verify it's an empty commit (no tree changes)
    local parent_tree=$(git rev-parse HEAD~1^{tree})
    local current_tree=$(git rev-parse HEAD^{tree})
    if [[ "$parent_tree" != "$current_tree" ]]; then
      echo "❌ ERROR: Annotation commit should be empty (no tree changes)"
      exit 1
    fi
    
    echo "✅ Annotation commit created correctly"

    # ═══════════════════════════════════════════════════════════
    # Verify: History branches exist (at least one per transplant)
    # ═══════════════════════════════════════════════════════════
    echo ""
    echo "🔍 Verifying history branches..."
    
    local history_branch_count=$(git branch --list "history/transplant-*" | wc -l)
    
    # We expect at least 1 branch (they might get deduplicated if same timestamp)
    if [[ $history_branch_count -lt 1 ]]; then
      echo "❌ ERROR: No history branches found"
      git branch --list "history/*" >&2
      exit 1
    fi
    
    echo "✅ History branches preserved ($history_branch_count branches)"
    echo "   Note: Branches may be deduplicated if created in same second"

    # ═══════════════════════════════════════════════════════════
    # SUCCESS
    # ═══════════════════════════════════════════════════════════
    echo ""
    echo "✅ SUCCESS: Multi-path merge completed and verified!"
    echo "   - 3 modules transplanted with full history"
    echo "   - All files present and correct"
    echo "   - Full history preserved for each module"
    echo "   - Empty annotation commit documents the operation"
    echo "   - History branches preserved for traceability"
    exit 0
  )

  result=$?
  rm -rf "$tmp_dir"

  pop_state PWD
  pop_state DEBUG

  return $result
}
