#!/usr/bin/env bash
test_githubPusher_readmeDescription() {
  echo "Testing repository description from README.md"

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
  local test_repo_name="src-test-readme-${timestamp}"

  if [[ -n ${DEBUG:-} ]]; then
    echo "DEBUG: Test repo name: $test_repo_name" >&2
    echo "DEBUG: Step 1 - Creating repo with README.md..." >&2
  fi

  # Create actual git repo with README.md
  local test_repo=$(mktemp -d)
  cd "$test_repo"
  git init >/dev/null 2>&1
  git config user.name "Test User" >/dev/null 2>&1
  git config user.email "test@example.com" >/dev/null 2>&1

  # Create README.md with a specific first line
  cat >README.md <<'EOF'
# Git History Extraction Tool

This is a tool for extracting git history from subdirectories.

## Features

- Fast extraction
- Preserves commit history
EOF

  git add . >/dev/null 2>&1
  git commit -m "Add README" >/dev/null 2>&1

  if [[ -n ${DEBUG:-} ]]; then
    echo "DEBUG: README.md contents:" >&2
    cat README.md >&2
  fi

  # Create meta.json
  local test_dir=$(mktemp -d)
  local meta_file="$test_dir/extract-git-path-meta.json"

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
    echo "DEBUG: Step 2 - Running github_pusher..." >&2
  fi

  # Create repository and push
  local output
  output=$(github_pusher "$meta_file" "false" 2>&1)
  local exit_code=$?

  rm -rf "$test_dir"
  rm -rf "$test_repo"

  if [[ $exit_code -ne 0 ]]; then
    echo "ERROR: github_pusher failed"
    echo "$output"
    return 1
  fi

  if [[ -n ${DEBUG:-} ]]; then
    echo "DEBUG: Step 3 - Fetching repo info from GitHub..." >&2
  fi

  # Verify description via API
  local repo_info
  repo_info=$(curl -s -H "Authorization: token $github_token" \
    "https://api.github.com/repos/$github_user/$test_repo_name")

  if [[ -n ${DEBUG:-} ]]; then
    echo "DEBUG: Repository info:" >&2
    echo "$repo_info" | jq '.' >&2
  fi

  local actual_description
  actual_description=$(echo "$repo_info" | jq -r '.description')

  if [[ -n ${DEBUG:-} ]]; then
    echo "DEBUG: Actual description: $actual_description" >&2
  fi

  # Expected description is first line without # and whitespace
  local expected_description="Git History Extraction Tool"

  if [[ $actual_description != "$expected_description" ]]; then
    echo "ERROR: Description mismatch"
    echo "Expected: $expected_description"
    echo "Actual: $actual_description"
    github_pusher_delete_repo "$github_user" "$test_repo_name" "$github_token" "false"
    return 1
  fi

  echo "Verified: Description matches README.md first line"

  # Cleanup
  github_pusher_delete_repo "$github_user" "$test_repo_name" "$github_token" "${DEBUG:-false}"
  echo "Repository deleted: ${test_repo_name}"

  echo "SUCCESS: README.md description works"
  return 0
}
