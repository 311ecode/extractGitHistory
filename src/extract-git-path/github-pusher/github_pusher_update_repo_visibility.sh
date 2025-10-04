#!/usr/bin/env bash
github_pusher_update_repo_visibility() {
    local owner="$1"
    local repo_name="$2"
    local private="$3"
    local github_token="$4"
    local debug="${5:-false}"
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: Updating repository visibility to private=$private" >&2
    fi
    
    local payload
    payload=$(jq -n --argjson private "$private" '{private: $private}')
    
    local response
    response=$(curl -s -X PATCH \
        -H "Authorization: token $github_token" \
        -H "Accept: application/vnd.github.v3+json" \
        -d "$payload" \
        "https://api.github.com/repos/$owner/$repo_name")
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: Visibility update response:" >&2
        echo "$response" | jq '.' >&2
    fi
    
    # Check if update was successful
    local updated_private
    updated_private=$(echo "$response" | jq -r '.private // empty')
    
    if [[ "$updated_private" == "$private" ]]; then
        return 0
    else
        if [[ "$debug" == "true" ]]; then
            echo "DEBUG: Visibility update may have failed or is pending" >&2
        fi
        return 0  # Don't fail the entire operation for visibility updates
    fi
}