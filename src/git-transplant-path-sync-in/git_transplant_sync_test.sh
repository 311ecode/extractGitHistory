#!/usr/bin/env bash

testGitTransplantWorkflow() {
  export LC_NUMERIC=C
  local debug="${DEBUG:-}"

  testFullSyncLoop() {
    echo "🧪 Testing Full Workflow: Mono -> GitHub -> External Commit -> Sync-In"

    # Ensure environment is ready for the Python logic
    export GITHUB_TOKEN="${GITHUB_TEST_TOKEN}"
    export GITHUB_USER="${GITHUB_TEST_USER:-311ecode}"

    if [[ -z "$GITHUB_TOKEN" ]]; then
      echo "❌ ERROR: GITHUB_TEST_TOKEN not set. Skipping test."
      return 1
    fi

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
    local generated_meta_path
    generated_meta_path=$(extract_git_path "$monorepo_dir/pkg/service" 2>/dev/null)
    
    if [[ ! -f "$generated_meta_path" ]]; then
       echo "❌ ERROR: extract_git_path failed to produce a valid metadata file."
       return 1
    fi

    # FIX: Use tail -n 1 to handle cases where the tool outputs "Repository exists" text
    local repo_url
    repo_url=$(github_create_repo "$generated_meta_path" --public | tail -n 1)
    
    if [[ -z "$repo_url" ]] || [[ ! "$repo_url" == *"github.com"* ]]; then
       echo "❌ ERROR: github_create_repo failed to return a valid URL. Output: $repo_url"
       return 1
    fi

    # 3. Simulate External Change in Polyrepo
    local poly_dir=$(mktemp -d)
    # Use -q and ensure we are cloning into the specific directory
    git clone "$repo_url" "$poly_dir" --quiet
    cd "$poly_dir" || return 1
    
    git config user.email "external@example.com"
    git config user.name "External Dev"
    echo "external change" >> main.go
    git add main.go && git commit -m "fix: external contribution" -q
    git push origin HEAD --quiet

    # 4. Sync-In back to Monorepo
    cd "$monorepo_dir" || return 1
    git_transplant_path_sync_in "$generated_meta_path" "$repo_url"

    # 5. Verification
    if grep -q "external change" pkg/service/main.go; then
      echo "✅ SUCCESS: External change brought home!"
      # Cleanup the remote repo after success
      cleanupGithubRepos -y "$(basename "$repo_url")"
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
