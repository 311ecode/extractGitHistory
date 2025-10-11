#!/usr/bin/env bash
github_sync_workflow_process_projects_helper() {
    local project="$1"
    local dry_run="$2"
    local debug="$3"
    
    # Normalize debug value
    if [[ "$debug" == "1" ]]; then
        debug="true"
    fi
    
    local github_user
    github_user=$(echo "$project" | jq -r '.github_user')
    
    local path
    path=$(echo "$project" | jq -r '.path')
    
    local repo_name
    repo_name=$(echo "$project" | jq -r '.repo_name')
    
    local private
    private=$(echo "$project" | jq -r '.private')
    
    local forcePush
    forcePush=$(echo "$project" | jq -r '.forcePush')
    
    local githubPages
    githubPages=$(echo "$project" | jq -r '.githubPages')
    
    local githubPagesBranch
    githubPagesBranch=$(echo "$project" | jq -r '.githubPagesBranch')
    
    local githubPagesPath
    githubPagesPath=$(echo "$project" | jq -r '.githubPagesPath')
    
    # Step 2a: Extract git history
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: process_projects_helper - Extracting git history from: $path" >&2
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
        return 1
    fi
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: process_projects_helper - Meta file created: $meta_file" >&2
    fi
    
    # Step 2b: Inject custom settings into meta.json
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: process_projects_helper - Injecting custom settings" >&2
        echo "DEBUG: process_projects_helper - repo_name: $repo_name" >&2
        echo "DEBUG: process_projects_helper - private: $private" >&2
        echo "DEBUG: process_projects_helper - forcePush: $forcePush" >&2
        echo "DEBUG: process_projects_helper - githubPages: $githubPages" >&2
        echo "DEBUG: process_projects_helper - githubPagesBranch: $githubPagesBranch" >&2
        echo "DEBUG: process_projects_helper - githubPagesPath: $githubPagesPath" >&2
    fi
    
    local temp_meta=$(mktemp)
    jq --arg repo_name "$repo_name" \
       --arg private "$private" \
       --arg forcePush "$forcePush" \
       --arg githubPages "$githubPages" \
       --arg githubPagesBranch "$githubPagesBranch" \
       --arg githubPagesPath "$githubPagesPath" \
       '.custom_repo_name = $repo_name | 
        .custom_private = $private | 
        .custom_forcePush = $forcePush |
        .custom_githubPages = $githubPages |
        .custom_githubPagesBranch = $githubPagesBranch |
        .custom_githubPagesPath = $githubPagesPath' \
       "$meta_file" > "$temp_meta"
    mv "$temp_meta" "$meta_file"
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: process_projects_helper - Updated meta.json:" >&2
        jq '.custom_repo_name, .custom_private, .custom_forcePush, .custom_githubPages, .custom_githubPagesBranch, .custom_githubPagesPath' "$meta_file" >&2
    fi
    
    # Step 2c: Push to GitHub - export DEBUG so github_pusher sees it
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: process_projects_helper - Pushing to GitHub as $github_user/$repo_name" >&2
        export DEBUG=true
    fi
    
    local github_url
    github_url=$(github_pusher "$meta_file" "$dry_run" 2>&1)
    local pusher_exit_code=$?
    
    if [[ $pusher_exit_code -ne 0 ]]; then
        echo "ERROR: GitHub push failed for $repo_name" >&2
        echo "$github_url" >&2
        return 1
    else
        echo "✓ Successfully synced: $github_url" >&2
        return 0
    fi
}