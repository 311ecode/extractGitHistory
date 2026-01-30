#!/usr/bin/env bash
# Date: 2026-01-30

test_githubSyncWorkflow2_integration() {
  echo "Testing Workflow V2 End-to-End with Sidecar"

  local github_token="${GITHUB_TEST_TOKEN}"
  local github_user="${GITHUB_TEST_ORG}"

  if [[ -z $github_token ]] || [[ -z $github_user ]]; then
    echo "SKIPPED: GITHUB_TEST_TOKEN and GITHUB_TEST_ORG required"
    return 0
  fi

  local timestamp=$(date +%s)
  local test_repo_name="sidecar-test-${timestamp}"

  # 1. Create Mock Monorepo Structure
  local monorepo=$(mktemp -d)
  local project_path="$monorepo/my-app"
  local sidecar_path="$monorepo/my-app-github-sync.d"
  
  mkdir -p "$project_path" "$sidecar_path"
  
  # Initialize Git in the project
  cd "$project_path"
  git init >/dev/null 2>&1
  git config user.name "Tester"
  git config user.email "test@example.com"
  echo "content" > file.txt
  git add . && git commit -m "initial commit" >/dev/null 2>&1
  cd - >/dev/null

  # Create Sidecar config
  cat > "$sidecar_path/sync" <<EOF
repo_name="${test_repo_name}"
private=true
EOF

  # 2. Execute Workflow V2
  local output
  output=$(github_sync_workflow2 "$monorepo" "false" "${DEBUG:-false}" 2>&1)
  local exit_code=$?

  # 3. Validation
  if [[ $exit_code -ne 0 ]]; then
    echo "ERROR: Workflow V2 execution failed" >&2
    echo "$output" >&2
    github_pusher_delete_repo "$github_user" "$test_repo_name" "$github_token" "false" 2>/dev/null
    rm -rf "$monorepo"
    return 1
  fi

  if ! github_pusher_check_repo_exists "$github_user" "$test_repo_name" "$github_token" "false"; then
    echo "ERROR: Repo not found on GitHub after workflow" >&2
    rm -rf "$monorepo"
    return 1
  fi

  echo "✓ Successfully verified sidecar-triggered sync for $test_repo_name"
  
  # Cleanup
  github_pusher_delete_repo "$github_user" "$test_repo_name" "$github_token" "false"
  rm -rf "$monorepo"
  return 0
}
