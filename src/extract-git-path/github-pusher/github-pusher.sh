#!/usr/bin/env bash
# GitHub repository creator for extracted git paths
# Creates GitHub repositories based on extract-git-path-meta.json

github_pusher_parse_meta_json() {
    local meta_file="$1"
    local debug="${2:-false}"
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: Parsing meta JSON: $meta_file" >&2
    fi
    
    if [[ ! -f "$meta_file" ]]; then
        echo "ERROR: Meta file not found: $meta_file" >&2
        return 1
    fi
    
    # Verify it's valid JSON
    if ! jq empty "$meta_file" 2>/dev/null; then
        echo "ERROR: Invalid JSON in meta file" >&2
        return 1
    fi
    
    return 0
}

github_pusher_generate_repo_name() {
    local meta_file="$1"
    local debug="${2:-false}"
    
    # Check if custom repo name exists (injected by workflow)
    local custom_repo_name
    custom_repo_name=$(jq -r '.custom_repo_name // empty' "$meta_file")
    
    if [[ -n "$custom_repo_name" ]] && [[ "$custom_repo_name" != "null" ]]; then
        if [[ "$debug" == "true" ]]; then
            echo "DEBUG: Using custom repo name: $custom_repo_name" >&2
        fi
        echo "$custom_repo_name"
        return 0
    fi
    
    # Otherwise derive from path
    local relative_path
    relative_path=$(jq -r '.relative_path' "$meta_file")
    
    if [[ "$relative_path" == "." ]]; then
        # Use last component of original repo root
        local original_root
        original_root=$(jq -r '.original_repo_root' "$meta_file")
        basename "$original_root"
    else
        # Use last component of relative path
        basename "$relative_path"
    fi
}

github_pusher_check_repo_exists() {
    local owner="$1"
    local repo_name="$2"
    local github_token="$3"
    local debug="${4:-false}"
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: Checking if repo exists: $owner/$repo_name" >&2
    fi
    
    local response
    response=$(curl -s -H "Authorization: token $github_token" \
        "https://api.github.com/repos/$owner/$repo_name")
    
    if echo "$response" | jq -e '.id' >/dev/null 2>&1; then
        if [[ "$debug" == "true" ]]; then
            echo "DEBUG: Repository exists" >&2
        fi
        return 0
    else
        if [[ "$debug" == "true" ]]; then
            echo "DEBUG: Repository does not exist" >&2
        fi
        return 1
    fi
}

github_pusher_create_repo() {
    local owner="$1"
    local repo_name="$2"
    local description="$3"
    local private="$4"
    local github_token="$5"
    local debug="${6:-false}"
    local dry_run="${7:-false}"
    
    if [[ "$dry_run" == "true" ]]; then
        echo "[DRY RUN] Would create repository: $owner/$repo_name" >&2
        echo "https://github.com/$owner/$repo_name"
        return 0
    fi
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: Creating repository: $owner/$repo_name" >&2
    fi
    
    local payload
    payload=$(jq -n \
        --arg name "$repo_name" \
        --arg desc "$description" \
        --argjson private "$private" \
        '{name: $name, description: $desc, private: $private, auto_init: false}')
    
    # Determine API endpoint - organization vs user
    local api_url
    local current_user
    current_user=$(curl -s -H "Authorization: token $github_token" \
        "https://api.github.com/user" | jq -r '.login')
    
    if [[ "$current_user" == "$owner" ]]; then
        # User repository
        api_url="https://api.github.com/user/repos"
        if [[ "$debug" == "true" ]]; then
            echo "DEBUG: Creating user repository" >&2
        fi
    else
        # Organization repository
        api_url="https://api.github.com/orgs/$owner/repos"
        if [[ "$debug" == "true" ]]; then
            echo "DEBUG: Creating organization repository" >&2
        fi
    fi
    
    local response
    response=$(curl -s -X POST \
        -H "Authorization: token $github_token" \
        -H "Accept: application/vnd.github.v3+json" \
        -d "$payload" \
        "$api_url")
    
    local repo_url
    repo_url=$(echo "$response" | jq -r '.html_url')
    
    if [[ "$repo_url" == "null" ]] || [[ -z "$repo_url" ]]; then
        echo "ERROR: Failed to create repository" >&2
        echo "Response: $response" >&2
        return 1
    fi
    
    echo "$repo_url"
    return 0
}

github_pusher_delete_repo() {
    local owner="$1"
    local repo_name="$2"
    local github_token="$3"
    local debug="${4:-false}"
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: Deleting repository: $owner/$repo_name" >&2
    fi
    
    curl -s -X DELETE \
        -H "Authorization: token $github_token" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$owner/$repo_name" >/dev/null
    
    return 0
}

github_pusher_update_meta_json() {
    local meta_file="$1"
    local github_url="$2"
    local github_owner="$3"
    local github_repo="$4"
    local synced_by="$5"
    local debug="${6:-false}"
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: Updating meta.json with sync status" >&2
    fi
    
    local synced_at
    synced_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Use jq to update sync_status in place
    local temp_file
    temp_file=$(mktemp)
    
    jq \
        --arg url "$github_url" \
        --arg owner "$github_owner" \
        --arg repo "$github_repo" \
        --arg synced_at "$synced_at" \
        --arg synced_by "$synced_by" \
        '.sync_status.synced = true |
         .sync_status.github_url = $url |
         .sync_status.github_owner = $owner |
         .sync_status.github_repo = $repo |
         .sync_status.synced_at = $synced_at |
         .sync_status.synced_by = $synced_by' \
        "$meta_file" > "$temp_file"
    
    if [[ $? -eq 0 ]]; then
        mv "$temp_file" "$meta_file"
        if [[ "$debug" == "true" ]]; then
            echo "DEBUG: Successfully updated meta.json" >&2
        fi
        return 0
    else
        echo "ERROR: Failed to update meta.json" >&2
        rm -f "$temp_file"
        return 1
    fi
}

github_pusher() {
    local meta_file="$1"
    local dry_run="${2:-false}"
    local debug="${DEBUG:-false}"
    
    # Use test credentials if available, otherwise regular credentials
    local github_token="${GITHUB_TEST_TOKEN:-${GITHUB_TOKEN}}"
    local github_user="${GITHUB_TEST_ORG:-${GITHUB_USER}}"
    
    # Validate environment
    if [[ -z "$github_token" ]]; then
        echo "ERROR: GITHUB_TOKEN or GITHUB_TEST_TOKEN environment variable not set" >&2
        return 1
    fi
    
    if [[ -z "$github_user" ]]; then
        echo "ERROR: GITHUB_USER or GITHUB_TEST_ORG environment variable not set" >&2
        return 1
    fi
    
    # Parse meta JSON
    if ! github_pusher_parse_meta_json "$meta_file" "$debug"; then
        return 1
    fi
    
    # Generate repository name
    local repo_name
    repo_name=$(github_pusher_generate_repo_name "$meta_file" "$debug")
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: Generated repo name: $repo_name" >&2
        echo "DEBUG: Target: $github_user/$repo_name" >&2
    fi
    
    # Check if repository exists
    if github_pusher_check_repo_exists "$github_user" "$repo_name" "$github_token" "$debug"; then
        local repo_url="https://github.com/$github_user/$repo_name"
        echo "Repository $github_user/$repo_name already exists"
        echo "$repo_url"
        
        # Update meta.json even if repo exists
        if [[ "$dry_run" != "true" ]]; then
            github_pusher_update_meta_json "$meta_file" "$repo_url" "$github_user" "$repo_name" "$github_user" "$debug"
        fi
        
        return 0
    fi
    
    # Create repository
    local original_path
    original_path=$(jq -r '.original_path' "$meta_file")
    local description="Extracted from $original_path"
    
    local repo_url
    repo_url=$(github_pusher_create_repo "$github_user" "$repo_name" "$description" "true" "$github_token" "$debug" "$dry_run")
    local create_status=$?
    
    if [[ $create_status -ne 0 ]]; then
        return 1
    fi
    
    # Handle dry-run mode
    if [[ "$dry_run" == "true" ]]; then
        echo ""
        echo "[DRY RUN] Proposed sync_status update:"
        cat <<EOF
{
  "sync_status": {
    "synced": true,
    "github_url": "https://github.com/$github_user/$repo_name",
    "github_owner": "$github_user",
    "github_repo": "$repo_name",
    "synced_at": "[DRY-RUN: would be populated with current timestamp]",
    "synced_by": "$github_user"
  }
}
EOF
        return 0
    fi
    
    # Update meta.json with sync status
    if ! github_pusher_update_meta_json "$meta_file" "$repo_url" "$github_user" "$repo_name" "$github_user" "$debug"; then
        return 1
    fi
    
    # Output the repository URL for the caller
    echo "$repo_url"
    return 0
}