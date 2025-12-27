#!/usr/bin/env bash
github_pusher_update_repo_visibility() {
    local owner="$1"
    local repo_name="$2"
    local private="$3"  # Now expects string "true" or "false"
    local github_token="$4"
    local debug="${5:-false}"
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: update_repo_visibility - Updating repository visibility to private=$private" >&2
        echo "DEBUG: update_repo_visibility - Repository: $owner/$repo_name" >&2
    fi
    
    # Convert string to boolean for JSON
    local private_bool
    if [[ "$private" == "false" ]]; then
        private_bool="false"
    else
        private_bool="true"
    fi
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: update_repo_visibility - Private (boolean for JSON): $private_bool" >&2
    fi
    
    local payload
    payload=$(jq -n --argjson private "$private_bool" '{private: $private}')
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: update_repo_visibility - Update payload:" >&2
        echo "$payload" | jq '.' >&2
        echo "DEBUG: update_repo_visibility - Sending PATCH request to: https://api.github.com/repos/$owner/$repo_name" >&2
    fi
    
    local temp_response
    local http_code
    
    # Use a temporary file to capture the response properly
    temp_response=$(mktemp)
    
    # Capture HTTP status code separately from body
    http_code=$(curl -s -w "%{http_code}" -o "$temp_response" -X PATCH \
        -H "Authorization: token $github_token" \
        -H "Accept: application/vnd.github.v3+json" \
        -d "$payload" \
        "https://api.github.com/repos/$owner/$repo_name")
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: update_repo_visibility - HTTP Status Code: $http_code" >&2
        echo "DEBUG: update_repo_visibility - Response body:" >&2
        jq '.' "$temp_response" 2>/dev/null || cat "$temp_response" >&2
        echo "DEBUG: update_repo_visibility - ---" >&2
    fi
    
    # Check HTTP status code
    if [[ "$http_code" != "200" ]]; then
        echo "ERROR: GitHub API returned HTTP $http_code" >&2
        
        # Try to parse error message
        local error_message
        error_message=$(jq -r '.message // empty' "$temp_response" 2>/dev/null)
        
        if [[ -n "$error_message" ]]; then
            echo "ERROR: GitHub API error: $error_message" >&2
            
            # Check for specific error types
            if echo "$error_message" | grep -qi "not have.*permission\|must have admin\|must be an admin"; then
                echo "ERROR: Your GitHub token does not have admin permissions for this repository" >&2
                echo "ERROR: Changing repository visibility requires admin access" >&2
            elif echo "$error_message" | grep -qi "organization"; then
                echo "ERROR: Organization policy may prevent changing repository visibility" >&2
            fi
        fi
        
        # Check for documentation_url
        local docs_url
        docs_url=$(jq -r '.documentation_url // empty' "$temp_response" 2>/dev/null)
        if [[ -n "$docs_url" ]]; then
            echo "ERROR: See: $docs_url" >&2
        fi
        
        rm -f "$temp_response"
        return 1
    fi
    
    # Check if response is valid JSON and contains the private field
    # Use 'has' instead of -e to check for field existence without testing truthiness
    if ! jq -e 'has("private")' "$temp_response" >/dev/null 2>&1; then
        echo "ERROR: Failed to read updated visibility from response" >&2
        if [[ "$debug" == "true" ]]; then
            echo "DEBUG: update_repo_visibility - Response missing .private field" >&2
            echo "DEBUG: update_repo_visibility - Raw response:" >&2
            cat "$temp_response" >&2
        fi
        rm -f "$temp_response"
        return 1
    fi
    
    # Read the updated value
    local updated_private
    updated_private=$(jq -r '.private' "$temp_response")
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: update_repo_visibility - Extracted .private value: '$updated_private'" >&2
    fi
    
    # Convert boolean back to string for comparison
    local updated_private_str
    if [[ "$updated_private" == "true" ]]; then
        updated_private_str="true"
    elif [[ "$updated_private" == "false" ]]; then
        updated_private_str="false"
    else
        echo "ERROR: Unexpected private value from API: '$updated_private'" >&2
        rm -f "$temp_response"
        return 1
    fi
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: update_repo_visibility - Current private value from API: $updated_private_str" >&2
        echo "DEBUG: update_repo_visibility - Requested private value: $private" >&2
    fi
    
    if [[ "$updated_private_str" != "$private" ]]; then
        echo "WARNING: Repository visibility mismatch!" >&2
        echo "WARNING: Requested: private=$private, Got: private=$updated_private_str" >&2
        echo "WARNING: This may be due to organization permissions or token scope" >&2
        
        if [[ "$debug" == "true" ]]; then
            echo "DEBUG: update_repo_visibility - The API accepted the request but the visibility didn't change" >&2
            echo "DEBUG: update_repo_visibility - This usually means organization settings override the request" >&2
        fi
        
        rm -f "$temp_response"
        return 1
    fi
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: update_repo_visibility - Successfully updated visibility to private=$updated_private_str" >&2
    fi
    
    # Clean up temp file
    rm -f "$temp_response"
    
    return 0
}
