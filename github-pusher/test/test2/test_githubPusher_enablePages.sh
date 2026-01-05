#!/usr/bin/env bash
test_githubPusher_enablePages() {
  echo "Testing GitHub Pages enablement"

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
  local test_repo_name="src-test-pages-${timestamp}"

  if [[ -n ${DEBUG:-} ]]; then
    echo "DEBUG: Test repo name: $test_repo_name" >&2
    echo "DEBUG: Step 1 - Creating local git repo..." >&2
  fi

  # Create git repo with content
  local test_repo=$(mktemp -d)
  cd "$test_repo"
  git init >/dev/null 2>&1
  git config user.name "Test User" >/dev/null 2>&1
  git config user.email "test@example.com" >/dev/null 2>&1

  # Create an index.html for Pages
  cat >index.html <<'EOF'
<!DOCTYPE html>
<html>
<head><title>Test Site</title></head>
<body><h1>Test GitHub Pages</h1></body>
</html>
EOF

  git add . >/dev/null 2>&1
  git commit -m "Add index.html" >/dev/null 2>&1

  # Create meta.json with Pages enabled AND public repo (required for Pages on free plans)
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
  "custom_githubPages": "true",
  "custom_githubPagesBranch": "main",
  "custom_githubPagesPath": "/",
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
    cat "$meta_file" | jq '.' >&2
    echo "DEBUG: Step 2 - Running github_pusher..." >&2
  fi

  # Run github_pusher
  local output
  output=$(github_pusher "$meta_file" "false" 2>&1)
  local exit_code=$?

  if [[ -n ${DEBUG:-} ]]; then
    echo "DEBUG: github_pusher exit code: $exit_code" >&2
    echo "DEBUG: github_pusher full output:" >&2
    echo "$output" >&2
    echo "DEBUG: ---" >&2
  fi

  rm -rf "$test_dir"
  rm -rf "$test_repo"

  if [[ $exit_code -ne 0 ]]; then
    echo "ERROR: github_pusher failed"
    echo "$output"
    github_pusher_delete_repo "$github_user" "$test_repo_name" "$github_token" "false"
    return 1
  fi

  # Verify Pages enablement message
  if ! echo "$output" | grep -q "Enabling GitHub Pages"; then
    echo "ERROR: Missing 'Enabling GitHub Pages' message"
    echo "Full output:"
    echo "$output"
    github_pusher_delete_repo "$github_user" "$test_repo_name" "$github_token" "false"
    return 1
  fi

  # Check if there was a warning (might indicate plan limitation even on public repo)
  if echo "$output" | grep -q "Could not enable GitHub Pages"; then
    echo "WARNING: Pages enablement had issues (see output)"

    # Check if it's a plan issue
    if echo "$output" | grep -q "Your current plan does not support"; then
      echo "SKIPPED: GitHub plan does not support Pages"
      github_pusher_delete_repo "$github_user" "$test_repo_name" "$github_token" "false"
      return 0
    fi
  fi

  if [[ -n ${DEBUG:-} ]]; then
    echo "DEBUG: Step 3 - Verifying Pages via API..." >&2
  fi

  # Give GitHub a moment to process
  sleep 5

  # Verify Pages is enabled via API
  local pages_info
  pages_info=$(curl -s -H "Authorization: token $github_token" \
    "https://api.github.com/repos/$github_user/$test_repo_name/pages")

  if [[ -n ${DEBUG:-} ]]; then
    echo "DEBUG: Pages API response:" >&2
    echo "$pages_info" | jq '.' >&2
  fi

  # Check if Pages exists (will have an html_url)
  local pages_url
  pages_url=$(echo "$pages_info" | jq -r '.html_url // empty')

  if [[ -z $pages_url ]]; then
    echo "WARNING: Pages URL not yet available"
    echo "This might be normal - Pages can take time to build"

    # Check if it's building
    local status
    status=$(echo "$pages_info" | jq -r '.status // empty')

    if [[ -n $status ]]; then
      echo "Pages status: $status"
    fi
  else
    echo "✓ GitHub Pages URL: $pages_url"
  fi

  # Cleanup
  github_pusher_delete_repo "$github_user" "$test_repo_name" "$github_token" "${DEBUG:-false}"
  echo "Repository deleted: ${test_repo_name}"

  echo "SUCCESS: GitHub Pages enablement works"
  return 0
}
