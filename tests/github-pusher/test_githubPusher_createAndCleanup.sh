#!/usr/bin/env bash
test_githubPusher_createAndCleanup() {
    echo "Testing actual repository creation and cleanup"
    
    # Use test-specific credentials
    local github_token="${GITHUB_TEST_TOKEN}"
    local github_user="${GITHUB_TEST_ORG}"
    
    # Check for required credentials
    if [[ -z "$github_token" ]] || [[ -z "$github_user" ]]; then
        echo "SKIPPED: GITHUB_TEST_TOKEN and GITHUB_TEST_ORG required"
        return 0
    fi
    
    # Generate unique test repo name with -test- in it
    local timestamp=$(date +%s)
    local test_repo_name="src-test-pusher-${timestamp}"
    
    local test_dir=$(mktemp -d)
    local meta_file="$test_dir/extract-git-path-meta.json"
    
    cat > "$meta_file" <<EOF
{
  "original_path": "/home/user/project/$test_repo_name",
  "original_repo_root": "/home/user/project",
  "relative_path": "$test_repo_name",
  "extracted_repo_path": "/tmp/extract_123/repo",
  "extraction_timestamp": "2025-01-15T10:00:00Z",
  "commit_mappings": {}
}
EOF
    
    # Create repository
    local output
    output=$(github_pusher "$meta_file" "false" 2>&1)
    local exit_code=$?
    
    rm -rf "$test_dir"
    
    if [[ $exit_code -ne 0 ]]; then
        echo "ERROR: Repository creation failed"
        echo "$output"
        return 1
    fi
    
    if ! echo "$output" | grep -q "https://github.com/${github_user}/${test_repo_name}"; then
        echo "ERROR: Repository URL not in output"
        echo "$output"
        return 1
    fi
    
    echo "Repository created: ${test_repo_name}"
    
    # Cleanup
    github_pusher_delete_repo "$github_user" "$test_repo_name" "$github_token" "false"
    echo "Repository deleted: ${test_repo_name}"
    
    echo "SUCCESS: Create and cleanup works"
    return 0
}