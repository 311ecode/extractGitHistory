#!/usr/bin/env bash
test_githubSyncWorkflow_withPages() {
    echo "Testing GitHub sync workflow with Pages enabled"
    
    # Use test-specific credentials
    local github_token="${GITHUB_TEST_TOKEN}"
    local github_user="${GITHUB_TEST_ORG}"
    
    # Check for required credentials
    if [[ -z "$github_token" ]] || [[ -z "$github_user" ]]; then
        echo "SKIPPED: GITHUB_TEST_TOKEN and GITHUB_TEST_ORG required"
        return 0
    fi
    
    # Generate unique test repo name
    local timestamp=$(date +%s)
    local test_repo_name="src-test-workflow-pages-${timestamp}"
    
    if [[ -n "${DEBUG:-}" ]]; then
        echo "DEBUG: Test repo name: $test_repo_name" >&2
        echo "DEBUG: Creating test git repo with website content..." >&2
    fi
    
    # Create test git repo with website content
    local test_repo=$(mktemp -d)
    cd "$test_repo"
    git init >/dev/null 2>&1
    git config user.name "Test User" >/dev/null 2>&1
    git config user.email "test@example.com" >/dev/null 2>&1
    
    # Create src directory with website files
    mkdir -p src
    cat > src/index.html <<'EOF'
<!DOCTYPE html>
<html>
<head><title>Test Site</title></head>
<body><h1>Hello from GitHub Pages</h1></body>
</html>
EOF
    
    cat > src/README.md <<'EOF'
# Test Website

This is a test website for GitHub Pages.
EOF
    
    git add . >/dev/null 2>&1
    git commit -m "Add website files" >/dev/null 2>&1
    
    if [[ -n "${DEBUG:-}" ]]; then
        echo "DEBUG: Repo structure:" >&2
        find . -type f | grep -v '\.git' >&2
    fi
    
    # Create YAML config with Pages enabled
    local config_dir=$(mktemp -d)
    local yaml_file="$config_dir/.github-sync.yaml"
    local json_output="$config_dir/projects.json"
    
    cat > "$yaml_file" <<EOF
github_user: ${github_user}
json_output: ${json_output}

projects:
  - path: ${test_repo}/src
    repo_name: ${test_repo_name}
    githubPages: true
    githubPagesBranch: main
    githubPagesPath: /
EOF
    
    if [[ -n "${DEBUG:-}" ]]; then
        echo "DEBUG: YAML config:" >&2
        cat "$yaml_file" >&2
    fi
    
    cd "$config_dir"
    
    # Run workflow
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
        github_pusher_delete_repo "$github_user" "$test_repo_name" "$github_token" "false"
        return 1
    fi
    
    # Verify Pages enablement in output
    if ! echo "$output" | grep -q "GitHub Pages: enabled"; then
        echo "ERROR: Missing 'GitHub Pages: enabled' in output"
        echo "$output"
        github_pusher_delete_repo "$github_user" "$test_repo_name" "$github_token" "false"
        return 1
    fi
    
    if ! echo "$output" | grep -q "Enabling GitHub Pages"; then
        echo "ERROR: Missing 'Enabling GitHub Pages' message"
        echo "$output"
        github_pusher_delete_repo "$github_user" "$test_repo_name" "$github_token" "false"
        return 1
    fi
    
    # Verify repo exists
    if ! github_pusher_check_repo_exists "$github_user" "$test_repo_name" "$github_token" "false"; then
        echo "ERROR: Repository was not created"
        echo "$output"
        return 1
    fi
    
    echo "Repository created: ${test_repo_name}"
    
    if [[ -n "${DEBUG:-}" ]]; then
        echo "DEBUG: Checking Pages status via API..." >&2
    fi
    
    # Give GitHub time to process Pages
    sleep 3
    
    # Check Pages via API
    local pages_info
    pages_info=$(curl -s -H "Authorization: token $github_token" \
        "https://api.github.com/repos/$github_user/$test_repo_name/pages")
    
    if [[ -n "${DEBUG:-}" ]]; then
        echo "DEBUG: Pages API response:" >&2
        echo "$pages_info" | jq '.' >&2
    fi
    
    local pages_url
    pages_url=$(echo "$pages_info" | jq -r '.html_url // empty')
    
    if [[ -n "$pages_url" ]]; then
        echo "✓ GitHub Pages URL: $pages_url"
    else
        echo "WARNING: Pages URL not yet available (may still be building)"
    fi
    
    # Cleanup
    github_pusher_delete_repo "$github_user" "$test_repo_name" "$github_token" "${DEBUG:-false}"
    echo "Repository deleted: ${test_repo_name}"
    
    echo "SUCCESS: Workflow with Pages works end-to-end"
    return 0
}