#!/usr/bin/env bash

testGitTransplantWorkflow() {
  export LC_NUMERIC=C
  local debug="${DEBUG:-}"

  testFullSyncLoop() {
    echo "🧪 Testing Full Workflow: Mono -> GitHub -> External Commit -> Sync-In"

    local tmp_dir=$(mktemp -d)
    local monorepo_dir="$tmp_dir/monorepo"
    
    # 1. Setup Local Monorepo
    mkdir -p "$monorepo_dir/pkg/service"
    cd "$monorepo_dir" || return 1
    git init -q
    git config user.email "test@example.com"
    git config user.name "Tester"
    echo "initial" > pkg/service/main.go
    git add . && git commit -m "feat: initial monorepo check-in" -q

    # 2. Extract & Create GitHub Repo
    local meta
    meta=$(extract_git_path "$monorepo_dir/pkg/service" 2>/dev/null)
    
    # NOTE: github_create_repo reads the name from meta
    local repo_url
    repo_url=$(github_create_repo "$meta" --public)
    
    if [[ -z "$repo_url" ]]; then
       echo "❌ ERROR: github_create_repo failed to return a URL"
       return 1
    fi

    # 3. Simulate External Change in Polyrepo
    local poly_dir=$(mktemp -d)
    git clone "$repo_url" "$poly_dir" --quiet
    cd "$poly_dir" || return 1
    git config user.email "external@example.com"
    git config user.name "External Dev"
    echo "external change" >> main.go
    git add main.go && git commit -m "fix: external contribution" -q
    git push origin HEAD --quiet

    # 4. Sync-In back to Monorepo
    cd "$monorepo_dir" || return 1
    git_transplant_path_sync_in "$meta" "$repo_url"

    # 5. Verification
    if grep -q "external change" pkg/service/main.go; then
      echo "✅ SUCCESS: External change brought home!"
      return 0
    else
      echo "❌ ERROR: Sync-In failed content check."
      return 1
    fi
  }

  local test_functions=("testFullSyncLoop")
  local ignored_tests=()
  bashTestRunner test_functions ignored_tests
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  testGitTransplantWorkflow
fi
