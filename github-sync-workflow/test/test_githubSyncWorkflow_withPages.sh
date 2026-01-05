#!/usr/bin/env bash
test_githubSyncWorkflow_withPages() {
  echo "Testing GitHub sync workflow with Pages enabled (Ultra-Verbose Real-time)"

  local github_token="${GITHUB_TEST_TOKEN}"
  local github_user="${GITHUB_TEST_ORG}"
  local debug_flag="${DEBUG:-false}"

  # Normalize debug for internal checks
  [[ $debug_flag == "1" ]] && debug_flag="true"

  if [[ -z $github_token ]] || [[ -z $github_user ]]; then
    echo "SKIPPED: GITHUB_TEST_TOKEN and GITHUB_TEST_ORG required"
    return 0
  fi

  local timestamp=$(date +%s)
  local test_repo_name="src-test-workflow-pages-${timestamp}"

  # --- SETUP PHASE ---
  local test_repo=$(mktemp -d)
  cd "$test_repo"
  git init >/dev/null 2>&1
  git config user.name "Test User"
  git config user.email "test@example.com"

  mkdir -p src
  echo "<html><body><h1>Hello from GitHub Pages</h1></body></html>" >src/index.html
  git add . >/dev/null 2>&1
  git commit -m "Add website files" >/dev/null 2>&1

  local config_dir=$(mktemp -d)
  local yaml_file="$config_dir/.github-sync.yaml"
  local json_output="$config_dir/projects.json"

  cat >"$yaml_file" <<EOF
github_user: ${github_user}
json_output: ${json_output}
projects:
  - path: ${test_repo}/src
    repo_name: ${test_repo_name}
    private: false
    githubPages: true
    githubPagesBranch: main
    githubPagesPath: /
EOF

  # --- EXECUTION PHASE (REAL-TIME DEBUG) ---
  cd "$config_dir"

  echo "DEBUG: Starting Workflow Execution..." >&2
  # Execute directly so stderr/stdout stream to the terminal in real-time
  github_sync_workflow "$yaml_file" "false" "$debug_flag"
  local exit_code=$?

  if [[ $exit_code -ne 0 ]]; then
    echo "ERROR: Workflow failed with exit code $exit_code" >&2
    github_pusher_delete_repo "$github_user" "$test_repo_name" "$github_token" "false"
    return 1
  fi

  # --- POLLING PHASE ---
  echo "DEBUG: Waiting for GitHub Pages to initialize..." >&2
  local max_attempts=20
  local attempt=1
  local site_live=false
  local pages_url="https://${github_user}.github.io/${test_repo_name}/"

  while [ $attempt -le $max_attempts ]; do
    # Use curl to check status and headers
    local header_dump=$(mktemp)
    local http_status=$(curl -s -o /dev/null -D "$header_dump" -I -w "%{http_code}" "$pages_url")

    echo "DEBUG: Attempt $attempt/$max_attempts - URL: $pages_url - Status: $http_status" >&2

    if [[ $debug_flag == "true" && $http_status != "200" ]]; then
      echo "DEBUG: HTTP Headers from GitHub:" >&2
      cat "$header_dump" | sed 's/^/  /' >&2
    fi
    rm -f "$header_dump"

    if [[ $http_status == "200" ]]; then
      echo "✓ Success: Site is live!"
      site_live=true
      break
    fi

    echo "DEBUG: Site not ready. Sleeping 10s..." >&2
    sleep 10
    ((attempt++))
  done

  # --- CONTENT VERIFICATION ---
  if [[ $site_live == "true" ]]; then
    local dl_content=$(curl -s "$pages_url")
    if [[ $dl_content == *"Hello from GitHub Pages"* ]]; then
      echo "✓ Content verified!"
    else
      echo "ERROR: Content mismatch! Downloaded: $dl_content" >&2
      site_live=false
    fi
  fi

  # Cleanup
  echo "DEBUG: Cleaning up test repository..." >&2
  github_pusher_delete_repo "$github_user" "$test_repo_name" "$github_token" "false"
  rm -rf "$test_repo" "$config_dir"

  if [[ $site_live == "true" ]]; then
    echo "SUCCESS: End-to-end Pages workflow verified."
    return 0
  else
    echo "FAILED: Test timed out or verification failed."
    return 1
  fi
}
