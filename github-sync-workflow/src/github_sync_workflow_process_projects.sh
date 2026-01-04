#!/usr/bin/env bash
github_sync_workflow_process_projects() {
    local json_output="$1"
    local dry_run="$2"
    local debug="$3"
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: [JSON_DUMP] Reading intermediate file: $json_output" >&2
        cat "$json_output" | jq '.' >&2
    fi
    
    local project_count=$(jq 'length' "$json_output")
    echo "Found $project_count project(s) to sync" >&2
    
    local success_count=0
    local fail_count=0
    
    for ((i=0; i<project_count; i++)); do
        local project=$(jq -c ".[$i]" "$json_output")
        local private=$(echo "$project" | jq -r '.private')
        local github_user=$(echo "$project" | jq -r '.github_user')
        local repo_name=$(echo "$project" | jq -r '.repo_name')
        local path=$(echo "$project" | jq -r '.path')
        local forcePush=$(echo "$project" | jq -r '.forcePush')
        local githubPages=$(echo "$project" | jq -r '.githubPages')
        local githubPagesBranch=$(echo "$project" | jq -r '.githubPagesBranch')
        local githubPagesPath=$(echo "$project" | jq -r '.githubPagesPath')
        
        echo "========================================" >&2
        echo "Processing: $github_user/$repo_name" >&2
        echo "Private: $private" >&2
        echo "========================================" >&2
        
        if ! github_sync_workflow_process_projects_helper "$project" "$dry_run" "$debug"; then
            ((fail_count++))
        else
            ((success_count++))
        fi
    done
    
    [[ $fail_count -gt 0 ]] && return 1 || return 0
}
