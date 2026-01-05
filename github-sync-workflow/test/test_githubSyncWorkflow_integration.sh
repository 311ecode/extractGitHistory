#!/usr/bin/env bash

test_githubSyncWorkflow_integration() {
  echo "Testing complete GitHub sync workflow with real repo creation"

  # Use test-specific credentials
  local github_token="${GITHUB_TEST_TOKEN}"
  local github_user="${GITHUB_TEST_ORG}"

  # Check for required credentials
  if [[ -z $github_token ]] || [[ -z $github_user ]]; then
    echo "SKIPPED: GITHUB_TEST_TOKEN and GITHUB_TEST_ORG required"
    return 0
  fi

  # Generate unique test repo name with -test- in it
  local timestamp=$(date +%s)
  local test_repo_name="src-test-workflow-${timestamp}"

  # Create test git repo with proper history
  local test_repo=$(mktemp -d)
  cd "$test_repo"
  git init >/dev/null 2>&1
  git config user.name "Test User" >/dev/null 2>&1
  git config user.email "test@example.com" >/dev/null 2>&1

  # Create src directory with multiple commits
  mkdir -p src
  echo "v1" >src/file.txt
  git add . >/dev/null 2>&1
  git commit -m "First commit" >/dev/null 2>&1

  echo "v2" >src/file.txt
  echo "another file" >src/another.txt
  git add . >/dev/null 2>&1
  git commit -m "Second commit" >/dev/null 2>&1

  echo "v3" >src/file.txt
  mkdir -p src/subdir
  echo "nested" >src/subdir/nested.txt
  git add . >/dev/null 2>&1
  git commit -m "Third commit" >/dev/null 2>&1

  if [[ -n ${DEBUG:-} ]]; then
    echo "DEBUG: Created test repo with commits:" >&2
    cd "$test_repo"
    git log --oneline >&2
    echo "DEBUG: Files in src/:" >&2
    find src -type f >&2
    cd - >/dev/null
  fi

  # Create YAML config
  local config_dir=$(mktemp -d)
  local yaml_file="$config_dir/.github-sync.yaml"
  local json_output="$config_dir/projects.json"

  cat >"$yaml_file" <<EOF
github_user: ${github_user}
json_output: ${json_output}

projects:
  - path: ${test_repo}/src
    repo_name: ${test_repo_name}
EOF

  cd "$config_dir"

  # Run actual workflow (not dry-run)
  local output
  output=$(github_sync_workflow "$yaml_file" "false" 2>&1)
  local exit_code=$?

  # Cleanup test repo and config
  cd - >/dev/null
  rm -rf "$test_repo"
  rm -rf "$config_dir"

  if [[ $exit_code -ne 0 ]]; then
    echo "ERROR: Workflow failed"
    echo "$output"
    # Try to cleanup GitHub repo if it was created
    github_pusher_delete_repo "$github_user" "$test_repo_name" "$github_token" "false" 2>/dev/null
    return 1
  fi

  # Verify repo was mentioned in output
  if ! echo "$output" | grep -q "$test_repo_name"; then
    echo "ERROR: Project name not in output"
    echo "$output"
    github_pusher_delete_repo "$github_user" "$test_repo_name" "$github_token" "false"
    return 1
  fi

  # Verify repo was actually created on GitHub
  if ! github_pusher_check_repo_exists "$github_user" "$test_repo_name" "$github_token" "false"; then
    echo "ERROR: Repository was not created on GitHub"
    echo "$output"
    return 1
  fi

  echo "Repository created: ${test_repo_name}"

  # Check repository contents via API
  if [[ -n ${DEBUG:-} ]]; then
    echo "DEBUG: Fetching repository info..." >&2
  fi

  local repo_info
  repo_info=$(curl -s -H "Authorization: token $github_token" \
    "https://api.github.com/repos/$github_user/$test_repo_name")

  if [[ -n ${DEBUG:-} ]]; then
    echo "DEBUG: Repository size: $(echo "$repo_info" | jq -r '.size') KB" >&2
    echo "DEBUG: Has default_branch field: $(echo "$repo_info" | jq 'has("default_branch")')" >&2
  fi

  local default_branch
  default_branch=$(echo "$repo_info" | jq -r '.default_branch // empty')

  if [[ -z $default_branch ]] || [[ $default_branch == "null" ]]; then
    echo "ERROR: Repository has no default branch - git history was not pushed!" >&2
    if [[ -n ${DEBUG:-} ]]; then
      echo "DEBUG: This means github_pusher only created an empty repo" >&2
      echo "DEBUG: The extracted git history was never pushed to GitHub" >&2
    fi
    github_pusher_delete_repo "$github_user" "$test_repo_name" "$github_token" "false"
    return 1
  fi

  if [[ -n ${DEBUG:-} ]]; then
    echo "DEBUG: Default branch: $default_branch" >&2

    # Get commit count
    local commits_url="https://api.github.com/repos/$github_user/$test_repo_name/commits"
    local commits
    commits=$(curl -s -H "Authorization: token $github_token" "$commits_url")

    # Check if it's an array
    if echo "$commits" | jq -e 'type == "array"' >/dev/null 2>&1; then
      local commit_count
      commit_count=$(echo "$commits" | jq 'length')
      echo "DEBUG: Number of commits on GitHub: $commit_count" >&2

      if [[ $commit_count -gt 0 ]]; then
        echo "DEBUG: Recent commits:" >&2
        echo "$commits" | jq -r '.[] | "  - \(.commit.message) (\(.sha[0:7]))"' 2>/dev/null || echo "  (could not parse commits)" >&2
      fi
    else
      echo "DEBUG: Commits API returned non-array response:" >&2
      echo "$commits" | jq '.' >&2
    fi

    # Get branch info
    echo "DEBUG: Fetching branch details..." >&2
    local branch_info
    branch_info=$(curl -s -H "Authorization: token $github_token" \
      "https://api.github.com/repos/$github_user/$test_repo_name/branches/$default_branch")

    echo "DEBUG: Branch response:" >&2
    echo "$branch_info" | jq '.' >&2
  fi

  # Get tree to list files
  local branch_info
  branch_info=$(curl -s -H "Authorization: token $github_token" \
    "https://api.github.com/repos/$github_user/$test_repo_name/branches/$default_branch")

  local tree_sha
  tree_sha=$(echo "$branch_info" | jq -r '.commit.commit.tree.sha // empty')

  if [[ -z $tree_sha ]] || [[ $tree_sha == "null" ]]; then
    echo "ERROR: Could not fetch tree SHA - branch may be empty" >&2
    if [[ -n ${DEBUG:-} ]]; then
      echo "DEBUG: Branch info response:" >&2
      echo "$branch_info" | jq '.' >&2
    fi
    github_pusher_delete_repo "$github_user" "$test_repo_name" "$github_token" "false"
    return 1
  fi

  if [[ -n ${DEBUG:-} ]]; then
    echo "DEBUG: Tree SHA: $tree_sha" >&2
    echo "DEBUG: Fetching repository contents..." >&2
  fi

  # Get recursive tree
  local tree_contents
  tree_contents=$(curl -s -H "Authorization: token $github_token" \
    "https://api.github.com/repos/$github_user/$test_repo_name/git/trees/$tree_sha?recursive=1")

  if [[ -n ${DEBUG:-} ]]; then
    echo "DEBUG: Repository file structure:" >&2
    echo "$tree_contents" | jq -r '.tree[]? | "  \(.type): \(.path)"' 2>/dev/null || echo "  (could not parse tree)" >&2
  fi

  # Count files
  local file_count
  file_count=$(echo "$tree_contents" | jq '[.tree[]? | select(.type == "blob")] | length' 2>/dev/null || echo "0")

  echo "Files in repository: $file_count"

  # We expect 3 files: file.txt, another.txt, subdir/nested.txt
  if [[ $file_count -lt 3 ]]; then
    echo "ERROR: Expected at least 3 files, found $file_count" >&2
    echo "ERROR: Git history was not properly pushed to GitHub" >&2
    github_pusher_delete_repo "$github_user" "$test_repo_name" "$github_token" "false"
    return 1
  fi

  # Verify success message in output
  if ! echo "$output" | grep -q "Successfully synced"; then
    echo "ERROR: Missing success message"
    echo "$output"
    github_pusher_delete_repo "$github_user" "$test_repo_name" "$github_token" "false"
    return 1
  fi

  # Verify summary shows success
  if ! echo "$output" | grep -q "Success: 1"; then
    echo "ERROR: Success count incorrect"
    echo "$output"
    github_pusher_delete_repo "$github_user" "$test_repo_name" "$github_token" "false"
    return 1
  fi

  # Cleanup GitHub repo
  github_pusher_delete_repo "$github_user" "$test_repo_name" "$github_token" "false"
  echo "Repository deleted: ${test_repo_name}"

  echo "SUCCESS: Complete workflow integration works"
  return 0
}
