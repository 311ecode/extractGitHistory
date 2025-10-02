#!/usr/bin/env bash
test_githubPusher_updatesMetaJson() {
    echo "Testing that github_pusher updates sync_status in meta.json"
    
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
    local test_repo_name="git-history-test-meta-${timestamp}"
    
    local test_dir=$(mktemp -d)
    local meta_file="$test_dir/extract-git-path-meta.json"
    
    # Create initial meta.json with sync_status initialized
    cat > "$meta_file" <<EOF
{
  "original_path": "/home/user/project/$test_repo_name",
  "original_repo_root": "/home/user/project",
  "relative_path": "$test_repo_name",
  "extracted_repo_path": "/tmp/extract_123/repo",
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
    
    # Run github_pusher
    local output
    output=$(github_pusher "$meta_file" "false" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        echo "ERROR: github_pusher failed"
        echo "$output"
        rm -rf "$test_dir"
        return 1
    fi
    
    # Verify sync_status was updated
    local synced
    synced=$(jq -r '.sync_status.synced' "$meta_file")
    
    if [[ "$synced" != "true" ]]; then
        echo "ERROR: sync_status.synced should be true, got: $synced"
        rm -rf "$test_dir"
        github_pusher_delete_repo "$github_user" "$test_repo_name" "$github_token" "false"
        return 1
    fi
    
    # Verify github_url
    local github_url
    github_url=$(jq -r '.sync_status.github_url' "$meta_file")
    
    if [[ "$github_url" != "https://github.com/${github_user}/${test_repo_name}" ]]; then
        echo "ERROR: Wrong github_url: $github_url"
        rm -rf "$test_dir"
        github_pusher_delete_repo "$github_user" "$test_repo_name" "$github_token" "false"
        return 1
    fi
    
    # Verify github_owner and github_repo
    local owner
    owner=$(jq -r '.sync_status.github_owner' "$meta_file")
    
    if [[ "$owner" != "$github_user" ]]; then
        echo "ERROR: Wrong github_owner: $owner"
        rm -rf "$test_dir"
        github_pusher_delete_repo "$github_user" "$test_repo_name" "$github_token" "false"
        return 1
    fi
    
    local repo
    repo=$(jq -r '.sync_status.github_repo' "$meta_file")
    
    if [[ "$repo" != "$test_repo_name" ]]; then
        echo "ERROR: Wrong github_repo: $repo"
        rm -rf "$test_dir"
        github_pusher_delete_repo "$github_user" "$test_repo_name" "$github_token" "false"
        return 1
    fi
    
    # Verify synced_at is populated
    local synced_at
    synced_at=$(jq -r '.sync_status.synced_at' "$meta_file")
    
    if [[ "$synced_at" == "null" ]] || [[ -z "$synced_at" ]]; then
        echo "ERROR: synced_at should be populated"
        rm -rf "$test_dir"
        github_pusher_delete_repo "$github_user" "$test_repo_name" "$github_token" "false"
        return 1
    fi
    
    # Verify synced_by
    local synced_by
    synced_by=$(jq -r '.sync_status.synced_by' "$meta_file")
    
    if [[ "$synced_by" != "$github_user" ]]; then
        echo "ERROR: Wrong synced_by: $synced_by"
        rm -rf "$test_dir"
        github_pusher_delete_repo "$github_user" "$test_repo_name" "$github_token" "false"
        return 1
    fi
    
    # Cleanup
    rm -rf "$test_dir"
    github_pusher_delete_repo "$github_user" "$test_repo_name" "$github_token" "false"
    
    echo "SUCCESS: sync_status correctly updated in meta.json"
    return 0
}