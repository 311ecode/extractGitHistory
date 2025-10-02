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
        echo "[DRY RUN] Would create repository: $owner/$repo_name"
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
        echo "Repository $github_user/$repo_name already exists"
        echo "https://github.com/$github_user/$repo_name"
        return 0
    fi
    
    # Create repository
    local original_path
    original_path=$(jq -r '.original_path' "$meta_file")
    local description="Extracted from $original_path"
    
    github_pusher_create_repo "$github_user" "$repo_name" "$description" "true" "$github_token" "$debug" "$dry_run"
    return $?
}