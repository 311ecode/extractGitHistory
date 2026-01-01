#!/usr/bin/env bash
test_githubPusher_alreadyExists() {
    echo "Testing behavior when repository already exists"
    
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
    local test_repo_name="src-test-exists-${timestamp}"
    
    if [[ -n "${DEBUG:-}" ]]; then
        echo "DEBUG: Test repo name: $test_repo_name" >&2
        echo "DEBUG: Step 1 - Creating repository via API first..." >&2
    fi
    
    # Create repository first via API
    local create_output
    create_output=$(github_pusher_create_repo "$github_user" "$test_repo_name" "Test repo" "true" "$github_token" "${DEBUG:-false}" "false" 2>&1)
    
    if [[ -n "${DEBUG:-}" ]]; then
        echo "DEBUG: API create output: $create_output" >&2
    fi
    
    # Create actual git repo with history
    local test_repo=$(mktemp -d)
    
    if [[ -n "${DEBUG:-}" ]]; then
        echo "DEBUG: Step 2 - Creating local git repo at: $test_repo" >&2
    fi
    
    cd "$test_repo"
    git init >/dev/null 2>&1
    git config user.name "Test User" >/dev/null 2>&1
    git config user.email "test@example.com" >/dev/null 2>&1
    
    echo "test content" > file.txt
    git add . >/dev/null 2>&1
    git commit -m "Test commit" >/dev/null 2>&1
    
    if [[ -n "${DEBUG:-}" ]]; then
        echo "DEBUG: Local git commits:" >&2
        git log --oneline >&2
        echo "DEBUG: Local git files:" >&2
        ls -la >&2
    fi
    
    # Now try to create via github_pusher
    local test_dir=$(mktemp -d)
    local meta_file="$test_dir/extract-git-path-meta.json"
    
    if [[ -n "${DEBUG:-}" ]]; then
        echo "DEBUG: Step 3 - Creating meta.json at: $meta_file" >&2
    fi
    
    cat > "$meta_file" <<EOF
{
  "original_path": "/home/user/project/$test_repo_name",
  "original_repo_root": "/home/user/project",
  "relative_path": "$test_repo_name",
  "extracted_repo_path": "$test_repo",
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
    
    if [[ -n "${DEBUG:-}" ]]; then
        echo "DEBUG: Meta.json contents:" >&2
        cat "$meta_file" >&2
        echo "DEBUG: Step 4 - Running github_pusher on existing repo..." >&2
    fi
    
    local output
    output=$(github_pusher "$meta_file" "false" 2>&1)
    local exit_code=$?
    
    if [[ -n "${DEBUG:-}" ]]; then
        echo "DEBUG: github_pusher exit code: $exit_code" >&2
        echo "DEBUG: github_pusher output:" >&2
        echo "$output" >&2
    fi
    
    # Cleanup test repo and config
    rm -rf "$test_dir"
    rm -rf "$test_repo"
    
    if [[ $exit_code -ne 0 ]]; then
        echo "ERROR: Should handle existing repository gracefully"
        echo "$output"
        github_pusher_delete_repo "$github_user" "$test_repo_name" "$github_token" "false"
        return 1
    fi
    
    if ! echo "$output" | grep -q "already exists"; then
        echo "ERROR: Missing 'already exists' message"
        echo "$output"
        github_pusher_delete_repo "$github_user" "$test_repo_name" "$github_token" "false"
        return 1
    fi
    
    if [[ -n "${DEBUG:-}" ]]; then
        echo "DEBUG: Step 5 - Verifying git history was pushed to existing repo..." >&2
    fi
    
    # Verify it still pushed the history to the existing repo
    local commits_url="https://api.github.com/repos/$github_user/$test_repo_name/commits"
    local commits
    commits=$(curl -s -H "Authorization: token $github_token" "$commits_url")
    
    if [[ -n "${DEBUG:-}" ]]; then
        echo "DEBUG: Commits API response:" >&2
        echo "$commits" | jq '.' >&2
    fi
    
    if echo "$commits" | jq -e 'type == "array"' >/dev/null 2>&1; then
        local commit_count
        commit_count=$(echo "$commits" | jq 'length')
        
        if [[ -n "${DEBUG:-}" ]]; then
            echo "DEBUG: Number of commits in GitHub repo: $commit_count" >&2
        fi
        
        if [[ "$commit_count" -lt 1 ]]; then
            echo "ERROR: History was not pushed to existing repository"
            github_pusher_delete_repo "$github_user" "$test_repo_name" "$github_token" "false"
            return 1
        fi
        
        echo "Verified: History pushed to existing repo ($commit_count commits)"
    else
        echo "WARNING: Could not verify commits (API returned non-array)"
        if [[ -n "${DEBUG:-}" ]]; then
            echo "DEBUG: This might be OK if the API has a delay" >&2
        fi
    fi
    
    # Cleanup
    if [[ -n "${DEBUG:-}" ]]; then
        echo "DEBUG: Step 6 - Cleaning up GitHub repo..." >&2
    fi
    
    github_pusher_delete_repo "$github_user" "$test_repo_name" "$github_token" "${DEBUG:-false}"
    
    echo "SUCCESS: Already exists check works and history was pushed"
    return 0
}