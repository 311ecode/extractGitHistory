#!/usr/bin/env bash
github_pusher() {
    local meta_file="$1"
    local dry_run="${2:-false}"
    local debug="${DEBUG:-false}"
    
    # Normalize debug value
    if [[ "$debug" == "1" ]]; then
        debug="true"
    fi
    
    # Use test credentials if available, otherwise regular credentials
    local github_token="${GITHUB_TEST_TOKEN:-${GITHUB_TOKEN}}"
    local github_user="${GITHUB_TEST_ORG:-${GITHUB_USER}}"
    
    # Validate environment
    if [[ -z "$github_token" ]]; then
        echo "ERROR: GITHUB_TOKEN or GITHUB_TEST_TOKEN environment variable not set" >&2
        return 1
    fi
    
    if [[ -z "$github_user" ]]; then
        echo "ERROR: GITHUB_USER or GITHUB_TEST_ORG environment variable not set" >&2
        return 1
    fi
    
    # Parse meta JSON
    if ! github_pusher_parse_meta_json "$meta_file" "$debug"; then
        return 1
    fi
    
    # Generate repository name
    local repo_name
    repo_name=$(github_pusher_generate_repo_name "$meta_file" "$debug")
    
    # Get extracted repo path
    local extracted_repo_path
    extracted_repo_path=$(jq -r '.extracted_repo_path' "$meta_file")
    
    # Get original path for description fallback
    local original_path
    original_path=$(jq -r '.original_path' "$meta_file")
    
    # Get description from README.md or use default
    local description
    description=$(github_pusher_get_description "$extracted_repo_path" "$original_path" "$debug")
    
    # Get private setting (default to "true" as string) - keep as string
    local private
    private=$(jq -r '.custom_private // "true"' "$meta_file")
    
    # Normalize string value
    if [[ "$private" == "false" ]] || [[ "$private" == "False" ]] || [[ "$private" == "FALSE" ]]; then
        private="false"
    else
        private="true"
    fi
    
    # Get forcePush setting (default to "true" as string)
    local forcePush
    forcePush=$(jq -r '.custom_forcePush // "true"' "$meta_file")
    
    # Normalize string value
    if [[ "$forcePush" == "false" ]] || [[ "$forcePush" == "False" ]] || [[ "$forcePush" == "FALSE" ]]; then
        forcePush="false"
    else
        forcePush="true"
    fi
    
    # Get GitHub Pages settings
    local githubPages
    githubPages=$(jq -r '.custom_githubPages // "false"' "$meta_file")
    
    # Normalize string value
    if [[ "$githubPages" == "true" ]] || [[ "$githubPages" == "True" ]] || [[ "$githubPages" == "TRUE" ]]; then
        githubPages="true"
    else
        githubPages="false"
    fi
    
    local githubPagesBranch
    githubPagesBranch=$(jq -r '.custom_githubPagesBranch // "main"' "$meta_file")
    
    local githubPagesPath
    githubPagesPath=$(jq -r '.custom_githubPagesPath // "/"' "$meta_file")
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: github_pusher - Generated repo name: $repo_name" >&2
        echo "DEBUG: github_pusher - Target: $github_user/$repo_name" >&2
        echo "DEBUG: github_pusher - Extracted repo: $extracted_repo_path" >&2
        echo "DEBUG: github_pusher - Description: $description" >&2
        echo "DEBUG: github_pusher - custom_private from meta: $(jq -r '.custom_private // "true"' "$meta_file")" >&2
        echo "DEBUG: github_pusher - Private setting (normalized): $private" >&2
        echo "DEBUG: github_pusher - custom_forcePush from meta: $(jq -r '.custom_forcePush // "true"' "$meta_file")" >&2
        echo "DEBUG: github_pusher - Force push setting (normalized): $forcePush" >&2
        echo "DEBUG: github_pusher - GitHub Pages enabled: $githubPages" >&2
        echo "DEBUG: github_pusher - GitHub Pages branch: $githubPagesBranch" >&2
        echo "DEBUG: github_pusher - GitHub Pages path: $githubPagesPath" >&2
    fi
    
    local repo_url
    local repo_existed=false
    
    # Check if repository exists
    if github_pusher_check_repo_exists "$github_user" "$repo_name" "$github_token" "$debug"; then
        repo_url="https://github.com/$github_user/$repo_name"
        echo "Repository $github_user/$repo_name already exists" >&2
        repo_existed=true
        
        if [[ "$dry_run" != "true" ]]; then
            # Update description
            echo "Updating repository description..." >&2
            github_pusher_update_repo_description "$github_user" "$repo_name" "$description" "$github_token" "$debug"
            
            # Update visibility - pass string value and debug flag
            echo "Updating repository visibility to private=$private..." >&2
            if github_pusher_update_repo_visibility "$github_user" "$repo_name" "$private" "$github_token" "$debug"; then
                echo "✓ Updated repository visibility to private=$private" >&2
            else
                echo "⚠ Could not update repository visibility (may require admin permissions)" >&2
                echo "⚠ You may need to change visibility manually at: $repo_url/settings" >&2
            fi
        else
            echo "[DRY RUN] Would update description and visibility (private=$private)" >&2
        fi
    else
        # Create repository - pass string value
        echo "Creating new repository $github_user/$repo_name..." >&2
        repo_url=$(github_pusher_create_repo "$github_user" "$repo_name" "$description" "$private" "$github_token" "$debug" "$dry_run")
        local create_status=$?
        
        if [[ $create_status -ne 0 ]]; then
            return 1
        fi
        
        if [[ "$debug" == "true" ]]; then
            echo "DEBUG: Repository created: $repo_url" >&2
        fi
        
        echo "✓ Created repository: $repo_url" >&2
    fi
    
    # Handle dry-run mode
    if [[ "$dry_run" == "true" ]]; then
        echo "$repo_url"
        echo ""
        echo "[DRY RUN] Proposed sync_status update:"
        cat <<EOF
{
  "sync_status": {
    "synced": true,
    "github_url": "https://github.com/$github_user/$repo_name",
    "github_owner": "$github_user",
    "github_repo": "$repo_name",
    "synced_at": "[DRY-RUN: would be populated with current timestamp]",
    "synced_by": "$github_user"
  }
}
EOF
        if [[ "$githubPages" == "true" ]]; then
            echo ""
            echo "[DRY RUN] Would enable GitHub Pages:"
            echo "  Branch: $githubPagesBranch"
            echo "  Path: $githubPagesPath"
        fi
        return 0
    fi
    
    # Push git history - now passing meta_file as 7th argument
    echo "Pushing git history (forcePush=$forcePush)..." >&2
    if ! github_pusher_push_git_history "$extracted_repo_path" "$github_user" "$repo_name" "$github_token" "$debug" "$dry_run" "$meta_file"; then
        if [[ "$repo_existed" == false ]]; then
            echo "WARNING: Created repo but failed to push - cleaning up..." >&2
            github_pusher_delete_repo "$github_user" "$repo_name" "$github_token" "$debug"
        fi
        return 1
    fi
    
    echo "✓ Git history pushed successfully" >&2
    
    # Enable GitHub Pages if requested
    if [[ "$githubPages" == "true" ]]; then
        echo "Enabling GitHub Pages (branch=$githubPagesBranch, path=$githubPagesPath)..." >&2
        if github_pusher_enable_pages "$github_user" "$repo_name" "$githubPagesBranch" "$githubPagesPath" "$github_token" "$debug" "$extracted_repo_path"; then
            echo "✓ GitHub Pages enabled successfully" >&2
        else
            echo "⚠ Could not enable GitHub Pages" >&2
            echo "⚠ You may need to enable it manually at: $repo_url/settings/pages" >&2
            # Don't fail the entire operation if Pages fails
        fi
    fi
    
    # Update meta.json with sync status
    if ! github_pusher_update_meta_json "$meta_file" "$repo_url" "$github_user" "$repo_name" "$github_user" "$debug"; then
        return 1
    fi
    
    # Output the repository URL for the caller
    echo "$repo_url"
    return 0
}