#!/usr/bin/env bash
github_pusher_create_repo() {
    local owner="$1"
    local repo_name="$2"
    local description="$3"
    local private="$4"
    local github_token="$5"
    local debug="${6:-false}"
    local dry_run="${7:-false}"
    
    # Convert string to boolean for JSON
    local private_bool="true"
    if [[ "$private" == "false" ]]; then
        private_bool="false"
    fi
    
    local payload=$(jq -n \
        --arg name "$repo_name" \
        --arg desc "$description" \
        --argjson private "$private_bool" \
        '{name: $name, description: $desc, private: $private, auto_init: false}')
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: [API_PAYLOAD_POST] URL: https://api.github.com/.../repos" >&2
        echo "DEBUG: [API_PAYLOAD_POST] Data: $payload" >&2
    fi
    
    if [[ "$dry_run" == "true" ]]; then
        echo "https://github.com/$owner/$repo_name"
        return 0
    fi

    local api_url="https://api.github.com/user/repos"
    # Note: Logic to switch to /orgs/$owner/repos is preserved in production but simplified for debug focus
    
    local response=$(curl -s -X POST \
        -H "Authorization: token $github_token" \
        -H "Accept: application/vnd.github.v3+json" \
        -d "$payload" \
        "$api_url")
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: [API_RESPONSE] Private field in response: $(echo "$response" | jq -r '.private')" >&2
    fi
    
    local repo_url=$(echo "$response" | jq -r '.html_url')
    if [[ "$repo_url" == "null" ]] || [[ -z "$repo_url" ]]; then
        echo "ERROR: Repo creation failed. Response: $response" >&2
        return 1
    fi
    echo "$repo_url"
}
