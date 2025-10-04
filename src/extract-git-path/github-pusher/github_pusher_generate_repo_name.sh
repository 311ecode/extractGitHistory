#!/usr/bin/env bash
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