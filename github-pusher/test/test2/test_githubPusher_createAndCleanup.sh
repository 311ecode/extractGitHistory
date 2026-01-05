#!/usr/bin/env bash
test_githubPusher_createAndCleanup() {
  echo "Testing actual repository creation with git push and cleanup"

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
  local test_repo_name="src-test-pusher-${timestamp}"

  if [[ -n ${DEBUG:-} ]]; then
    echo "DEBUG: Test repo name: $test_repo_name" >&2
    echo "DEBUG: GitHub user: $github_user" >&2
    echo "DEBUG: Step 1 - Creating local git repo with history..." >&2
  fi

  # Create actual git repo with history
  local test_repo=$(mktemp -d)
  cd "$test_repo"
  git init >/dev/null 2>&1
  git config user.name "Test User" >/dev/null 2>&1
  git config user.email "test@example.com" >/dev/null 2>&1

  echo "test content v1" >file.txt
  git add . >/dev/null 2>&1
  git commit -m "Test commit 1" >/dev/null 2>&1

  echo "test content v2" >file.txt
  echo "another file" >another.txt
  git add . >/dev/null 2>&1
  git commit -m "Test commit 2" >/dev/null 2>&1

  if [[ -n ${DEBUG:-} ]]; then
    echo "DEBUG: Local repo path: $test_repo" >&2
    echo "DEBUG: Local commits:" >&2
    git log --oneline >&2
    echo "DEBUG: Local files:" >&2
    ls -la >&2
  fi

  # Create meta.json
  local test_dir=$(mktemp -d)
  local meta_file="$test_dir/extract-git-path-meta.json"

  if [[ -n ${DEBUG:-} ]]; then
    echo "DEBUG: Step 2 - Creating meta.json..." >&2
  fi

  cat >"$meta_file" <<EOF
{
  "original_path": "/home/user/project/$test_repo_name",
  "original_repo_root": "/home/user/project",
  "relative_path": "$test_repo_name",
  "extracted_repo_path": "$test_repo",
  "extraction_timestamp": "2025-01-15T10:00:00Z",
  "commit_mappings": {},
  "sync_status": {
    "synced": false,
    "github_url": null,
    "github_owner": null,
    "github_repo": null,
    "synced_at": null,
    "synced_by": null
  }
}
EOF

  if [[ -n ${DEBUG:-} ]]; then
    echo "DEBUG: Meta file: $meta_file" >&2
    echo "DEBUG: Step 3 - Running github_pusher..." >&2
  fi

  # Create repository and push
  local output
  output=$(github_pusher "$meta_file" "false" 2>&1)
  local exit_code=$?

  if [[ -n ${DEBUG:-} ]]; then
    echo "DEBUG: github_pusher exit code: $exit_code" >&2
    echo "DEBUG: github_pusher output:" >&2
    echo "$output" >&2
  fi

  rm -rf "$test_dir"
  rm -rf "$test_repo"

  if [[ $exit_code -ne 0 ]]; then
    echo "ERROR: Repository creation/push failed"
    echo "$output"
    return 1
  fi

  if ! echo "$output" | grep -q "https://github.com/${github_user}/${test_repo_name}"; then
    echo "ERROR: Repository URL not in output"
    echo "$output"
    github_pusher_delete_repo "$github_user" "$test_repo_name" "$github_token" "false"
    return 1
  fi

  echo "Repository created: ${test_repo_name}"

  if [[ -n ${DEBUG:-} ]]; then
    echo "DEBUG: Step 4 - Verifying commits via GitHub API..." >&2
  fi

  # Verify git history was pushed via API
  local commits_url="https://api.github.com/repos/$github_user/$test_repo_name/commits"
  local commits
  commits=$(curl -s -H "Authorization: token $github_token" "$commits_url")

  if [[ -n ${DEBUG:-} ]]; then
    echo "DEBUG: Commits API response:" >&2
    echo "$commits" | jq '.' >&2
  fi

  if ! echo "$commits" | jq -e 'type == "array"' >/dev/null 2>&1; then
    echo "ERROR: Could not fetch commits from GitHub"
    echo "$commits"
    github_pusher_delete_repo "$github_user" "$test_repo_name" "$github_token" "false"
    return 1
  fi

  local commit_count
  commit_count=$(echo "$commits" | jq 'length')

  if [[ $commit_count -lt 2 ]]; then
    echo "ERROR: Expected at least 2 commits, found $commit_count"
    github_pusher_delete_repo "$github_user" "$test_repo_name" "$github_token" "false"
    return 1
  fi

  echo "Verified: $commit_count commit(s) pushed to GitHub"

  if [[ -n ${DEBUG:-} ]]; then
    echo "DEBUG: Commit messages:" >&2
    echo "$commits" | jq -r '.[] | "  - \(.commit.message)"' >&2
  fi

  if [[ -n ${DEBUG:-} ]]; then
    echo "DEBUG: Step 5 - Verifying files via GitHub API..." >&2
  fi

  # Verify files exist
  local tree_info
  tree_info=$(curl -s -H "Authorization: token $github_token" \
    "https://api.github.com/repos/$github_user/$test_repo_name/branches/main")

  if [[ -n ${DEBUG:-} ]]; then
    echo "DEBUG: Branch info:" >&2
    echo "$tree_info" | jq '.' >&2
  fi

  local tree_sha
  tree_sha=$(echo "$tree_info" | jq -r '.commit.commit.tree.sha // empty')

  if [[ -n $tree_sha ]]; then
    local tree_contents
    tree_contents=$(curl -s -H "Authorization: token $github_token" \
      "https://api.github.com/repos/$github_user/$test_repo_name/git/trees/$tree_sha")

    if [[ -n ${DEBUG:-} ]]; then
      echo "DEBUG: Tree contents:" >&2
      echo "$tree_contents" | jq '.' >&2
    fi

    local file_count
    file_count=$(echo "$tree_contents" | jq '[.tree[]? | select(.type == "blob")] | length')

    if [[ $file_count -lt 2 ]]; then
      echo "ERROR: Expected at least 2 files, found $file_count"
      github_pusher_delete_repo "$github_user" "$test_repo_name" "$github_token" "false"
      return 1
    fi

    echo "Verified: $file_count file(s) in repository"

    if [[ -n ${DEBUG:-} ]]; then
      echo "DEBUG: Files in repo:" >&2
      echo "$tree_contents" | jq -r '.tree[]? | "  \(.type): \(.path)"' >&2
    fi
  fi

  # Cleanup
  if [[ -n ${DEBUG:-} ]]; then
    echo "DEBUG: Step 6 - Cleaning up..." >&2
  fi

  github_pusher_delete_repo "$github_user" "$test_repo_name" "$github_token" "${DEBUG:-false}"
  echo "Repository deleted: ${test_repo_name}"

  echo "SUCCESS: Create, push, and cleanup works"
  return 0
}
