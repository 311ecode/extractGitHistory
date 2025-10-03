#!/usr/bin/env bash
# YAML scanner for extracting GitHub repository metadata

yaml_scanner_parse_config() {
    local yaml_file="$1"
    local debug="${2:-false}"
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: Parsing YAML config: $yaml_file" >&2
    fi
    
    if [[ ! -f "$yaml_file" ]]; then
        echo "ERROR: YAML file not found: $yaml_file" >&2
        return 1
    fi
    
    # Check if yq is available
    if ! command -v yq >/dev/null 2>&1; then
        echo "ERROR: yq is not installed (install: pip install yq)" >&2
        return 1
    fi
    
    return 0
}

yaml_scanner_extract_github_user() {
    local yaml_file="$1"
    local debug="${2:-false}"
    
    # Try direct github_user key (Python yq with jq syntax)
    local github_user
    github_user=$(yq -r '.github_user // empty' "$yaml_file" 2>/dev/null)
    
    if [[ -n "$github_user" ]] && [[ "$github_user" != "null" ]]; then
        echo "$github_user"
        return 0
    fi
    
    # Try nested github.user format
    github_user=$(yq -r '.github.user // empty' "$yaml_file" 2>/dev/null)
    
    if [[ -n "$github_user" ]] && [[ "$github_user" != "null" ]]; then
        echo "$github_user"
        return 0
    fi
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: No github_user found in YAML" >&2
    fi
    
    return 1
}

yaml_scanner_extract_repo_name() {
    local yaml_file="$1"
    local debug="${2:-false}"
    
    # First try to get repo_name directly
    local repo_name
    repo_name=$(yq -r '.repo_name // empty' "$yaml_file" 2>/dev/null)
    
    if [[ -n "$repo_name" ]] && [[ "$repo_name" != "null" ]]; then
        echo "$repo_name"
        return 0
    fi
    
    # Try nested github.repo format
    repo_name=$(yq -r '.github.repo // empty' "$yaml_file" 2>/dev/null)
    
    if [[ -n "$repo_name" ]] && [[ "$repo_name" != "null" ]]; then
        echo "$repo_name"
        return 0
    fi
    
    # If no repo_name, try to get from path
    local repo_path
    repo_path=$(yq -r '.path // empty' "$yaml_file" 2>/dev/null)
    
    if [[ -z "$repo_path" ]] || [[ "$repo_path" == "null" ]]; then
        repo_path=$(yq -r '.repo_path // empty' "$yaml_file" 2>/dev/null)
    fi
    
    if [[ -n "$repo_path" ]] && [[ "$repo_path" != "null" ]]; then
        # Extract last directory from path
        repo_name=$(basename "$repo_path")
        echo "$repo_name"
        return 0
    fi
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: No repo_name or path found in YAML" >&2
    fi
    
    return 1
}

yaml_scanner() {
    local yaml_file="${1:-.github-sync.yaml}"
    local debug="${DEBUG:-false}"
    
    # If no argument provided, look for default file in current directory
    if [[ ! -f "$yaml_file" ]]; then
        echo "ERROR: YAML file not found: $yaml_file" >&2
        return 1
    fi
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: Scanning YAML file: $yaml_file" >&2
        echo "DEBUG: YAML contents:" >&2
        cat "$yaml_file" >&2
    fi
    
    # Parse and validate YAML
    if ! yaml_scanner_parse_config "$yaml_file" "$debug"; then
        return 1
    fi
    
    # Extract GitHub user
    local github_user
    github_user=$(yaml_scanner_extract_github_user "$yaml_file" "$debug")
    local user_status=$?
    
    if [[ $user_status -ne 0 ]] || [[ -z "$github_user" ]]; then
        echo "ERROR: Could not extract github_user from YAML" >&2
        return 1
    fi
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: Extracted github_user: $github_user" >&2
    fi
    
    # Extract repo name
    local repo_name
    repo_name=$(yaml_scanner_extract_repo_name "$yaml_file" "$debug")
    local repo_status=$?
    
    if [[ $repo_status -ne 0 ]] || [[ -z "$repo_name" ]]; then
        echo "ERROR: Could not extract repo_name or path from YAML" >&2
        return 1
    fi
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: Extracted repo_name: $repo_name" >&2
    fi
    
    # Output as JSON
    cat <<EOF
{
  "github_user": "$github_user",
  "repo_name": "$repo_name"
}
EOF
    
    return 0
}