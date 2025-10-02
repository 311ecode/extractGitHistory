#!/usr/bin/env bash
test_extractGitPath_syncStatusInitialized() {
    echo "Testing that sync_status is initialized in extract-git-path-meta.json"
    
    # Create test repo
    local test_repo=$(mktemp -d)
    cd "$test_repo"
    git init >/dev/null 2>&1
    git config user.name "Test User" >/dev/null 2>&1
    git config user.email "test@example.com" >/dev/null 2>&1
    
    mkdir -p project/src
    echo "content" > project/src/file.txt
    git add . >/dev/null 2>&1
    git commit -m "Initial commit" >/dev/null 2>&1
    
    # Extract path
    local stderr_capture=$(mktemp)
    local meta_file
    meta_file=$(extract_git_path "$test_repo/project/src" 2>"$stderr_capture")
    local exit_code=$?
    local repo_path=$(tail -1 "$stderr_capture")
    rm -f "$stderr_capture"
    
    # Cleanup test repo
    rm -rf "$test_repo"
    
    if [[ $exit_code -ne 0 ]]; then
        echo "ERROR: Function failed"
        [[ -n "$meta_file" ]] && rm -rf "$(dirname "$meta_file")" 2>/dev/null
        return 1
    fi
    
    if [[ ! -f "$meta_file" ]]; then
        echo "ERROR: extract-git-path-meta.json does not exist"
        return 1
    fi
    
    # Verify sync_status exists
    if ! jq -e '.sync_status' "$meta_file" >/dev/null 2>&1; then
        echo "ERROR: sync_status field missing from meta.json"
        rm -rf "$(dirname "$meta_file")"
        return 1
    fi
    
    # Verify sync_status fields are initialized correctly
    local synced
    synced=$(jq -r '.sync_status.synced' "$meta_file")
    
    if [[ "$synced" != "false" ]]; then
        echo "ERROR: sync_status.synced should be false, got: $synced"
        rm -rf "$(dirname "$meta_file")"
        return 1
    fi
    
    # Verify all fields are null
    local fields=("github_url" "github_owner" "github_repo" "synced_at" "synced_by")
    for field in "${fields[@]}"; do
        local value
        value=$(jq -r ".sync_status.$field" "$meta_file")
        if [[ "$value" != "null" ]]; then
            echo "ERROR: sync_status.$field should be null, got: $value"
            rm -rf "$(dirname "$meta_file")"
            return 1
        fi
    done
    
    # Cleanup
    rm -rf "$(dirname "$meta_file")"
    
    echo "SUCCESS: sync_status correctly initialized in extract-git-path-meta.json"
    return 0
}