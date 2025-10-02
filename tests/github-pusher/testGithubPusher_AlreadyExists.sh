#!/usr/bin/env bash
testGithubPusher_AlreadyExists() {
    echo "Testing behavior when repository already exists"
    
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
    local test_repo_name="git-history-test-exists-${timestamp}"
    
    # Create repository first via API
    github_pusher_create_repo "$github_user" "$test_repo_name" "Test repo" "true" "$github_token" "false" "false" >/dev/null
    
    # Now try to create via github_pusher
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
    
    local output
    output=$(github_pusher "$meta_file" "false" 2>&1)
    local exit_code=$?
    
    rm -rf "$test_dir"
    
    # Cleanup
    github_pusher_delete_repo "$github_user" "$test_repo_name" "$github_token" "false"
    
    if [[ $exit_code -ne 0 ]]; then
        echo "ERROR: Should handle existing repository gracefully"
        echo "$output"
        return 1
    fi
    
    if ! echo "$output" | grep -q "already exists"; then
        echo "ERROR: Missing 'already exists' message"
        echo "$output"
        return 1
    fi
    
    echo "SUCCESS: Already exists check works"
    return 0
}