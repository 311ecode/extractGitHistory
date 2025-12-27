#!/usr/bin/env bash

testGitTransplantWorkflow() {
  export LC_NUMERIC=C
  local debug="${DEBUG:-}"
  
  testMirrorParityDeterministic() {
    local run_id=$(head /dev/urandom | tr -dc a-z0-9 | head -c 6)
    echo "🧪 Testing Protocol: Round-Trip (ID: $run_id)"

    export GITHUB_TOKEN="${GITHUB_TEST_TOKEN}"
    export GITHUB_USER="${GITHUB_TEST_USER:-311ecode}"
    
    local test_repo_name="sync-test-${run_id}"
    local sub_path="pkg/service-${run_id}"

    local tmp_dir=$(mktemp -d)
    local monorepo_dir="$tmp_dir/monorepo"
    
    # 1. Setup Monorepo
    mkdir -p "$monorepo_dir/$sub_path"
    cd "$monorepo_dir" || return 1
    git init -q
    git config user.email "test@example.com"
    git config user.name "Tester"
    echo "initial" > "$sub_path/main.go"
    git add . && git commit -m "feat: initial" -q

    # 2. Extract & Baseline Push
    local meta_a_file=$(extract_git_path "$monorepo_dir/$sub_path" 2>/dev/null)
    local updated_meta=$(jq --arg name "$test_repo_name" '.custom_repo_name = $name' "$meta_a_file")
    echo "$updated_meta" > "$meta_a_file"

    local repo_url_a=$(github_create_repo "$meta_a_file" --public | tail -n 1)
    local repo_dir_a=$(jq -r '.extracted_repo_path' "$meta_a_file")

    cd "$repo_dir_a" && git remote add origin "$repo_url_a" 2>/dev/null
    git push -u origin HEAD --force --quiet

    # 3. External Work
    local poly_tmp=$(mktemp -d)
    git clone "$repo_url_a" "$poly_tmp" --quiet
    cd "$poly_tmp" || return 1
    git config user.email "test@example.com"
    git config user.name "Tester"
    
    echo "ext 1" >> main.go && git commit -am "external 1" -q
    echo "ext 2" >> main.go && git commit -am "external 2" -q
    git push origin HEAD --quiet
    local head_expected=$(git rev-parse HEAD)

    # 4. Sync-In
    cd "$monorepo_dir" || return 1
    git_transplant_path_sync_in "$meta_a_file" "$repo_url_a"

    # 5. Re-Extract and Compare
    local meta_b_file=$(extract_git_path "$monorepo_dir/$sub_path" 2>/dev/null)
    local repo_dir_b=$(jq -r '.extracted_repo_path' "$meta_b_file")
    
    cd "$repo_dir_b" || return 1
    local head_actual=$(git rev-parse HEAD)

    echo "📊 Parity Comparison:"
    echo "   Source Polyrepo (A): $head_expected"
    echo "   Re-extracted Poly (B): $head_actual"

    if [[ "$head_expected" == "$head_actual" ]]; then
      echo "✅ SUCCESS: Perfect parity achieved!"
      cleanupGithubRepos -y "$test_repo_name"
      return 0
    else
      echo "❌ ERROR: Hash Mismatch."
      if [[ -n "$debug" ]]; then
         diff -u <(cd "$poly_tmp" && git cat-file -p "$head_expected") \
                 <(cd "$repo_dir_b" && git cat-file -p "$head_actual") >&2 || true
      fi
      return 1
    fi
  }

  local test_functions=("testMirrorParityDeterministic")
  local ignored_tests=()
  bashTestRunner test_functions ignored_tests
}
