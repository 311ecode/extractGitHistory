#!/usr/bin/env bash
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
        echo "[DRY RUN] Description: $description" >&2
        echo "https://github.com/$owner/$repo_name"
        return 0
    fi
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: Creating repository: $owner/$repo_name" >&2
        echo "DEBUG: Description: $description" >&2
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