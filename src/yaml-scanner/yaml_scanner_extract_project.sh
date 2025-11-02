#!/usr/bin/env bash
yaml_scanner_extract_project() {
    local yaml_file="$1"
    local github_user="$2"
    local index="$3"
    local debug="${4:-false}"
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: yaml_scanner_extract_project - Processing project at index $index" >&2
    fi
    
    # Extract project path and repo_name
    local path
    path=$(yq eval ".projects[$index].path" "$yaml_file")
    
    if [[ -z "$path" ]] || [[ "$path" == "null" ]]; then
        echo "ERROR: Project at index $index has no path" >&2
        return 1
    fi
    
    # Resolve relative paths from YAML file location
    local resolved_path
    if [[ "$path" = /* ]]; then
        # Absolute path - use as-is
        resolved_path="$path"
    else
        # Relative path - resolve from YAML file directory
        local yaml_dir
        yaml_dir="$(cd "$(dirname "$yaml_file")" && pwd)"
        
        # Handle ./ prefix if present
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
    repo_name=$(yq eval ".projects[$index].repo_name" "$yaml_file")
    
    if [[ -z "$repo_name" ]] || [[ "$repo_name" == "null" ]]; then
        repo_name=$(basename "$resolved_path")
    fi
    
    # Extract private setting with proper boolean handling
    local private
    local private_raw
    
    # First, check what yq actually returns
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: Extracting private field from YAML..." >&2
        echo "DEBUG: Running: yq eval '.projects[$index].private' \"$yaml_file\"" >&2
    fi
    
    private_raw=$(yq eval ".projects[$index].private" "$yaml_file")
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: yq returned: '$private_raw' (type: $(printf '%s' "$private_raw" | wc -c) chars)" >&2
        echo "DEBUG: Checking if empty/null..." >&2
    fi
    
    if [[ -z "$private_raw" ]] || [[ "$private_raw" == "null" ]]; then
        # Not specified - default to "true"
        private="true"
        if [[ "$debug" == "true" ]]; then
            echo "DEBUG: No private setting found (empty or null), defaulting to 'true'" >&2
        fi
    else
        # Normalize the value
        if [[ "$debug" == "true" ]]; then
            echo "DEBUG: Normalizing private value: '$private_raw'" >&2
        fi
        
        if [[ "$private_raw" == "false" ]] || [[ "$private_raw" == "False" ]] || [[ "$private_raw" == "FALSE" ]]; then
            private="false"
            if [[ "$debug" == "true" ]]; then
                echo "DEBUG: Normalized to 'false'" >&2
            fi
        else
            private="true"
            if [[ "$debug" == "true" ]]; then
                echo "DEBUG: Normalized to 'true' (from: '$private_raw')" >&2
            fi
        fi
    fi
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: Final private value: '$private'" >&2
    fi
    
    # Extract forcePush setting with proper boolean handling
    local forcePush
    local forcePush_raw
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: Extracting forcePush field from YAML..." >&2
    fi
    
    forcePush_raw=$(yq eval ".projects[$index].forcePush" "$yaml_file")
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: forcePush yq returned: '$forcePush_raw'" >&2
    fi
    
    if [[ -z "$forcePush_raw" ]] || [[ "$forcePush_raw" == "null" ]]; then
        # Not specified - default to "true"
        forcePush="true"
        if [[ "$debug" == "true" ]]; then
            echo "DEBUG: No forcePush setting found, defaulting to 'true'" >&2
        fi
    else
        # Normalize the value
        if [[ "$debug" == "true" ]]; then
            echo "DEBUG: Normalizing forcePush value: '$forcePush_raw'" >&2
        fi
        
        if [[ "$forcePush_raw" == "false" ]] || [[ "$forcePush_raw" == "False" ]] || [[ "$forcePush_raw" == "FALSE" ]]; then
            forcePush="false"
            if [[ "$debug" == "true" ]]; then
                echo "DEBUG: Normalized forcePush to 'false'" >&2
            fi
        else
            forcePush="true"
            if [[ "$debug" == "true" ]]; then
                echo "DEBUG: Normalized forcePush to 'true' (from: '$forcePush_raw')" >&2
            fi
        fi
    fi
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: Final forcePush value: '$forcePush'" >&2
    fi
    
    # Extract GitHub Pages settings
    local githubPages
    local githubPages_raw
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: Extracting githubPages field from YAML..." >&2
    fi
    
    githubPages_raw=$(yq eval ".projects[$index].githubPages" "$yaml_file")
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: githubPages yq returned: '$githubPages_raw'" >&2
    fi
    
    if [[ -z "$githubPages_raw" ]] || [[ "$githubPages_raw" == "null" ]]; then
        # Not specified - default to "false"
        githubPages="false"
        if [[ "$debug" == "true" ]]; then
            echo "DEBUG: No githubPages setting found, defaulting to 'false'" >&2
        fi
    else
        # Normalize the value
        if [[ "$debug" == "true" ]]; then
            echo "DEBUG: Normalizing githubPages value: '$githubPages_raw'" >&2
        fi
        
        if [[ "$githubPages_raw" == "true" ]] || [[ "$githubPages_raw" == "True" ]] || [[ "$githubPages_raw" == "TRUE" ]]; then
            githubPages="true"
            if [[ "$debug" == "true" ]]; then
                echo "DEBUG: Normalized githubPages to 'true'" >&2
            fi
        else
            githubPages="false"
            if [[ "$debug" == "true" ]]; then
                echo "DEBUG: Normalized githubPages to 'false' (from: '$githubPages_raw')" >&2
            fi
        fi
    fi
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: Final githubPages value: '$githubPages'" >&2
    fi
    
    # Extract githubPagesBranch - only meaningful if githubPages=true
    local githubPagesBranch
    githubPagesBranch=$(yq eval ".projects[$index].githubPagesBranch" "$yaml_file")
    
    if [[ -z "$githubPagesBranch" ]] || [[ "$githubPagesBranch" == "null" ]]; then
        githubPagesBranch="main"  # Default branch
        if [[ "$debug" == "true" ]]; then
            echo "DEBUG: No githubPagesBranch specified, defaulting to 'main'" >&2
        fi
    fi
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: Final githubPagesBranch value: '$githubPagesBranch'" >&2
    fi
    
    # Extract githubPagesPath - only meaningful if githubPages=true
    local githubPagesPath
    githubPagesPath=$(yq eval ".projects[$index].githubPagesPath" "$yaml_file")
    
    if [[ -z "$githubPagesPath" ]] || [[ "$githubPagesPath" == "null" ]]; then
        githubPagesPath="/"  # Default path (root)
        if [[ "$debug" == "true" ]]; then
            echo "DEBUG: No githubPagesPath specified, defaulting to '/'" >&2
        fi
    fi
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: Final githubPagesPath value: '$githubPagesPath'" >&2
    fi
    
    # Build JSON object with all settings as strings
    local json_output
    json_output=$(cat <<EOF
{
  "github_user": "$github_user",
  "path": "$resolved_path",
  "repo_name": "$repo_name",
  "private": "$private",
  "forcePush": "$forcePush",
  "githubPages": "$githubPages",
  "githubPagesBranch": "$githubPagesBranch",
  "githubPagesPath": "$githubPagesPath"
}
EOF
)
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: Generated JSON for project $index:" >&2
        echo "$json_output" | jq '.' >&2
    fi
    
    echo "$json_output"
    
    return 0
}
