#!/usr/bin/env bash
github_sync_workflow_process_projects() {
    local json_output="$1"
    local dry_run="$2"
    local debug="$3"
    
    # Step 2: Process each project
    local project_count
    project_count=$(jq 'length' "$json_output")
    
    echo "Found $project_count project(s) to sync" >&2
    echo "" >&2
    
    local success_count=0
    local fail_count=0
    
    for ((i=0; i<project_count; i++)); do
        local project
        project=$(jq -c ".[$i]" "$json_output")
        
        local github_user
        github_user=$(echo "$project" | jq -r '.github_user')
        
        local path
        path=$(echo "$project" | jq -r '.path')
        
        local repo_name
        repo_name=$(echo "$project" | jq -r '.repo_name')
        
        local private
        private=$(echo "$project" | jq -r '.private')
        
        echo "========================================" >&2
        echo "Processing: $github_user/$repo_name" >&2
        echo "Path: $path" >&2
        echo "Private: $private" >&2
        echo "========================================" >&2
        
        # Process individual project
        if ! github_sync_workflow_process_projects_helper "$project" "$dry_run" "$debug"; then
            ((fail_count++))
        else
            ((success_count++))
        fi
        
        echo "" >&2
    done
    
    # Summary
    echo "========================================" >&2
    echo "Sync Complete" >&2
    echo "========================================" >&2
    echo "Success: $success_count" >&2
    echo "Failed:  $fail_count" >&2
    echo "" >&2
    
    if [[ $fail_count -gt 0 ]]; then
        return 1
    fi
    
    return 0
}

