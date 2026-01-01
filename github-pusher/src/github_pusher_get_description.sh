#!/usr/bin/env bash
github_pusher_get_description() {
    local extracted_repo_path="$1"
    local original_path="$2"
    local debug="${3:-false}"
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: Looking for README.md in: $extracted_repo_path" >&2
    fi
    
    # Check if README.md exists
    if [[ -f "$extracted_repo_path/README.md" ]]; then
        # Get first non-empty line
        local first_line
        first_line=$(grep -m 1 -v '^[[:space:]]*$' "$extracted_repo_path/README.md" | sed 's/^[#[:space:]]*//')
        
        if [[ -n "$first_line" ]]; then
            if [[ "$debug" == "true" ]]; then
                echo "DEBUG: Using first line from README.md: $first_line" >&2
            fi
            echo "$first_line"
            return 0
        fi
    fi
    
    # Fallback to extracted from path
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: No README.md found, using default description" >&2
    fi
    echo "Extracted from $original_path"
}