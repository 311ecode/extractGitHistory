#!/usr/bin/env bash
yaml_scanner_extract_project() {
    local yaml_file="$1"
    local github_user="$2"
    local index="$3"
    local debug="${4:-false}"
    
    # Extract project path and repo_name
    local path
    path=$(yq -r ".projects[$index].path // empty" "$yaml_file")
    
    if [[ -z "$path" ]]; then
        echo "ERROR: Project at index $index has no path" >&2
        return 1
    fi
    
    # Resolve relative paths
    local resolved_path
    if [[ "$path" = /* ]]; then
        # Absolute path - use as-is
        resolved_path="$path"
    else
        # Relative path - resolve from YAML file directory
        local yaml_dir
        yaml_dir="$(cd "$(dirname "$yaml_file")" && pwd)"
        
        # Handle ./ and plain relative paths
        if [[ "$path" == ./* ]]; then
            path="${path#./}"
        fi
        
        resolved_path="$yaml_dir/$path"
        
        # Verify the resolved path exists
        if [[ ! -e "$resolved_path" ]]; then
            echo "ERROR: Cannot resolve relative path: $path (resolved to: $resolved_path)" >&2
            return 1
        fi
        
        if [[ "$debug" == "true" ]]; then
            echo "DEBUG: Resolved relative path '$path' to '$resolved_path'" >&2
        fi
    fi
    
    # Extract repo_name or derive from path
    local repo_name
    repo_name=$(yq -r ".projects[$index].repo_name // empty" "$yaml_file")
    
    if [[ -z "$repo_name" ]]; then
        repo_name=$(basename "$resolved_path")
    fi
    
    # Extract private setting (default to true)
    local private
    private=$(yq -r ".projects[$index].private // \"true\"" "$yaml_file")
    
    # Build JSON object
    cat <<EOF
{
  "github_user": "$github_user",
  "path": "$resolved_path",
  "repo_name": "$repo_name",
  "private": $private
}
EOF
    
    return 0
}