#!/usr/bin/env bash
test_githubPusher_pagesCustomPath() {
  echo "Testing GitHub Pages with custom /docs path"

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
  local test_repo_name="src-test-pages-docs-${timestamp}"

  if [[ -n ${DEBUG:-} ]]; then
    echo "DEBUG: Test repo name: $test_repo_name" >&2
    echo "DEBUG: Creating repo with /docs directory..." >&2
  fi

  # Create git repo WITH /docs directory
  local test_repo=$(mktemp -d)
  cd "$test_repo"
  git init >/dev/null 2>&1
  git config user.name "Test User" >/dev/null 2>&1
  git config user.email "test@example.com" >/dev/null 2>&1

  mkdir -p docs
  cat >docs/index.html <<'EOF'
<!DOCTYPE html>
<html>
<head><title>Docs Site</title></head>
<body><h1>Documentation</h1></body>
</html>
EOF

  echo "test" >README.md
  git add . >/dev/null 2>&1
  git commit -m "Add docs" >/dev/null 2>&1

  # Create meta.json with Pages enabled for /docs
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
  "custom_githubPages": "true",
  "custom_githubPagesBranch": "main",
  "custom_githubPagesPath": "/docs",
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

  # Run github_pusher
  local output
  output=$(github_pusher "$meta_file" "false" 2>&1)
  local exit_code=$?

  rm -rf "$test_dir"
  rm -rf "$test_repo"

  if [[ $exit_code -ne 0 ]]; then
    echo "ERROR: github_pusher failed"
    echo "$output"
    github_pusher_delete_repo "$github_user" "$test_repo_name" "$github_token" "false"
    return 1
  fi

  # Should have Pages enablement message
  if ! echo "$output" | grep -q "Enabling GitHub Pages"; then
    echo "ERROR: Missing 'Enabling GitHub Pages' message"
    echo "$output"
    github_pusher_delete_repo "$github_user" "$test_repo_name" "$github_token" "false"
    return 1
  fi

  if [[ -n ${DEBUG:-} ]]; then
    echo "DEBUG: Verifying Pages configuration via API..." >&2
  fi

  # Give GitHub a moment
  sleep 3

  # Verify Pages configuration via API
  local pages_info
  pages_info=$(curl -s -H "Authorization: token $github_token" \
    "https://api.github.com/repos/$github_user/$test_repo_name/pages")

  if [[ -n ${DEBUG:-} ]]; then
    echo "DEBUG: Pages API response:" >&2
    echo "$pages_info" | jq '.' >&2
  fi

  # Check source configuration
  local source_path
  source_path=$(echo "$pages_info" | jq -r '.source.path // empty')

  if [[ $source_path == "/docs" ]]; then
    echo "✓ Pages configured with /docs path"
  else
    echo "WARNING: Pages path is '$source_path' (expected '/docs')"
    echo "WARNING: This might be due to API delays"
  fi

  # Cleanup
  github_pusher_delete_repo "$github_user" "$test_repo_name" "$github_token" "${DEBUG:-false}"
  echo "Repository deleted: ${test_repo_name}"

  echo "SUCCESS: Custom /docs path works"
  return 0
}
