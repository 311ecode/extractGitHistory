#!/usr/bin/env bash
test_githubPusher_updateVisibility() {
  echo "Testing repository visibility update for existing repo"

  # Use test-specific credentials
  local github_token="${GITHUB_TEST_TOKEN}"
  local github_user="${GITHUB_TEST_ORG}"

  # Check for required credentials
  if [[ -z $github_token ]] || [[ -z $github_user ]]; then
    echo "SKIPPED: GITHUB_TEST_TOKEN and GITHUB_TEST_ORG required"
    return 0
  fi

  # Generate unique test repo name
  local timestamp=$(date +%s)
  local test_repo_name="src-test-visibility-${timestamp}"

  if [[ -n ${DEBUG:-} ]]; then
    echo "DEBUG: Test repo name: $test_repo_name" >&2
    echo "DEBUG: Step 1 - Creating private repo..." >&2
  fi

  # Create initial private repository
  github_pusher_create_repo "$github_user" "$test_repo_name" "Test repo" "true" "$github_token" "${DEBUG:-false}" "false" >/dev/null

  # Create git repo with history
  local test_repo=$(mktemp -d)

  if [[ -n ${DEBUG:-} ]]; then
    echo "DEBUG: Test repo created at: $test_repo" >&2
  fi

  cd "$test_repo"
  git init >/dev/null 2>&1
  git config user.name "Test User" >/dev/null 2>&1
  git config user.email "test@example.com" >/dev/null 2>&1

  echo "test content" >file.txt
  git add . >/dev/null 2>&1
  git commit -m "Test commit" >/dev/null 2>&1

  # Create meta.json with private="false" as STRING (should make it public)
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
  "custom_private": "false",
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
    echo "DEBUG: Meta file contents:" >&2
    cat "$meta_file" >&2
    echo "DEBUG: Step 2 - Running github_pusher to update to public..." >&2
  fi

  sleep 2

  # Run github_pusher (should update to public)
  local output
  output=$(DEBUG=1 github_pusher "$meta_file" "false" 2>&1)
  local exit_code=$?

  sleep 2

  if [[ -n ${DEBUG:-} ]]; then
    echo "DEBUG: github_pusher full output:" >&2
    echo "$output" >&2
    echo "DEBUG: Exit code: $exit_code" >&2
  fi

  # Don't delete test_repo yet - github_pusher needs it

  if [[ $exit_code -ne 0 ]]; then
    echo "ERROR: github_pusher failed"
    echo "$output"
    rm -rf "$test_dir"
    rm -rf "$test_repo"
    github_pusher_delete_repo "$github_user" "$test_repo_name" "$github_token" "false"
    return 1
  fi

  # Now cleanup
  rm -rf "$test_dir"
  rm -rf "$test_repo"

  if [[ -n ${DEBUG:-} ]]; then
    echo "DEBUG: Step 3 - Verifying visibility via API..." >&2
  fi

  # Give GitHub a moment to process the update
  sleep 2

  # Verify visibility was updated via API
  local repo_info
  repo_info=$(curl -s -H "Authorization: token $github_token" \
    "https://api.github.com/repos/$github_user/$test_repo_name")

  if [[ -n ${DEBUG:-} ]]; then
    echo "DEBUG: Repository info:" >&2
    echo "$repo_info" | jq '.' >&2
  fi

  local is_private
  is_private=$(echo "$repo_info" | jq -r '.private')

  if [[ $is_private != "false" ]]; then
    echo "ERROR: Repository should be public (private=false), got: $is_private"
    github_pusher_delete_repo "$github_user" "$test_repo_name" "$github_token" "false"
    return 1
  fi

  echo "Verified: Repository visibility updated to public"

  # Cleanup
  github_pusher_delete_repo "$github_user" "$test_repo_name" "$github_token" "${DEBUG:-false}"
  echo "Repository deleted: ${test_repo_name}"

  echo "SUCCESS: Visibility update works"
  return 0
}
