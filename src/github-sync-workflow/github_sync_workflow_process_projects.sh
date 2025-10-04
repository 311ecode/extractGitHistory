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
        
        # Step 2a: Extract git history
        if [[ "$debug" == "true" ]]; then
            echo "DEBUG: Extracting git history from: $path" >&2
        fi
        
        local stderr_capture=$(mktemp)
        local meta_file
        
        if [[ "$debug" == "true" ]]; then
            meta_file=$(extract_git_path "$path" 2> >(tee "$stderr_capture" >&2))
        else
            meta_file=$(extract_git_path "$path" 2>"$stderr_capture")
        fi
        
        local extract_exit_code=$?
        rm -f "$stderr_capture"
        
        if [[ $extract_exit_code -ne 0 ]]; then
            echo "ERROR: Git extraction failed for $path" >&2
            ((fail_count++))
            echo "" >&2
            continue
        fi
        
        if [[ "$debug" == "true" ]]; then
            echo "DEBUG: Meta file created: $meta_file" >&2
        fi
        
        # Step 2b: Inject custom repo_name and private setting into meta.json
        if [[ "$debug" == "true" ]]; then
            echo "DEBUG: Injecting custom repo_name: $repo_name" >&2
            echo "DEBUG: Injecting private setting: $private" >&2
        fi
        
        local temp_meta=$(mktemp)
        # Use --arg for repo_name and raw boolean value for private
        jq --arg repo_name "$repo_name" \
            '.custom_repo_name = $repo_name | .custom_private = (if "'"$private"'" == "true" then true else false end)' \
            "$meta_file" > "$temp_meta"
        mv "$temp_meta" "$meta_file"
        
        if [[ "$debug" == "true" ]]; then
            echo "DEBUG: Updated meta.json:" >&2
            jq '.custom_repo_name, .custom_private' "$meta_file" >&2
        fi
        
        # Step 2c: Push to GitHub
        if [[ "$debug" == "true" ]]; then
            echo "DEBUG: Pushing to GitHub as $github_user/$repo_name" >&2
        fi
        
        local github_url
        github_url=$(github_pusher "$meta_file" "$dry_run" 2>&1)
        local pusher_exit_code=$?
        
        if [[ $pusher_exit_code -ne 0 ]]; then
            echo "ERROR: GitHub push failed for $repo_name" >&2
            echo "$github_url" >&2
            ((fail_count++))
        else
            echo "✓ Successfully synced: $github_url" >&2
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