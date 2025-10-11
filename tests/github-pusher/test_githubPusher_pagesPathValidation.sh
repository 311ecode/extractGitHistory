#!/usr/bin/env bash
test_githubPusher_pagesPathValidation() {
    echo "Testing GitHub Pages path validation"
    
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
    local test_repo_name="src-test-pages-path-${timestamp}"
    
    if [[ -n "${DEBUG:-}" ]]; then
        echo "DEBUG: Test repo name: $test_repo_name" >&2
        echo "DEBUG: Testing with non-existent /docs path..." >&2
    fi
    
    # Create git repo WITHOUT /docs directory
    local test_repo=$(mktemp -d)
    cd "$test_repo"
    git init >/dev/null 2>&1
    git config user.name "Test User" >/dev/null 2>&1
    git config user.email "test@example.com" >/dev/null 2>&1
    
    echo "test" > README.md
    git add . >/dev/null 2>&1
    git commit -m "Initial commit" >/dev/null 2>&1
    
    # Create meta.json with Pages enabled for /docs (which doesn't exist)
    local test_dir=$(mktemp -d)
    local meta_file="$test_dir/extract-git-path-meta.json"
    
    cat > "$meta_file" <<EOF
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
    
    # Should succeed overall (repo created/pushed) even if Pages fails
    if [[ $exit_code -ne 0 ]]; then
        echo "ERROR: github_pusher should succeed even if Pages fails"
        echo "$output"
        github_pusher_delete_repo "$github_user" "$test_repo_name" "$github_token" "false"
        return 1
    fi
    
    # But should have warning about path validation
    if ! echo "$output" | grep -q "does not exist"; then
        echo "ERROR: Missing path validation error message"
        echo "$output"
        github_pusher_delete_repo "$github_user" "$test_repo_name" "$github_token" "false"
        return 1
    fi
    
    if ! echo "$output" | grep -q "Could not enable GitHub Pages"; then
        echo "ERROR: Missing 'Could not enable' warning"
        echo "$output"
        github_pusher_delete_repo "$github_user" "$test_repo_name" "$github_token" "false"
        return 1
    fi
    
    # Cleanup
    github_pusher_delete_repo "$github_user" "$test_repo_name" "$github_token" "${DEBUG:-false}"
    echo "Repository deleted: ${test_repo_name}"
    
    echo "SUCCESS: Path validation works correctly"
    return 0
}