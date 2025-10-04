#!/usr/bin/env bash
github_pusher_push_git_history() {
    local extracted_repo_path="$1"
    local owner="$2"
    local repo_name="$3"
    local github_token="$4"
    local debug="${5:-false}"
    local dry_run="${6:-false}"
    
    if [[ "$dry_run" == "true" ]]; then
        echo "[DRY RUN] Would push git history from: $extracted_repo_path" >&2
        return 0
    fi
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: Pushing git history to GitHub..." >&2
        echo "DEBUG: Source: $extracted_repo_path" >&2
        echo "DEBUG: Target: $owner/$repo_name" >&2
    fi
    
    if [[ ! -d "$extracted_repo_path" ]]; then
        echo "ERROR: Extracted repo path not found: $extracted_repo_path" >&2
        return 1
    fi
    
    cd "$extracted_repo_path" || return 1
    
    # Check if it's a git repo
    if [[ ! -d .git ]]; then
        echo "ERROR: Not a git repository: $extracted_repo_path" >&2
        cd - >/dev/null
        return 1
    fi
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: Commits to push:" >&2
        git log --oneline >&2
    fi
    
    # Set remote URL with token for authentication
    local remote_url="https://${github_token}@github.com/${owner}/${repo_name}.git"
    
    # Add remote
    if ! git remote add origin "$remote_url" 2>/dev/null; then
        # Remote might already exist
        git remote set-url origin "$remote_url" 2>/dev/null
    fi
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: Pushing to origin..." >&2
    fi
    
    # Get current branch name
    local branch_name
    branch_name=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "master")
    
    # Push to main (GitHub's default)
    if ! git push -u origin "${branch_name}:main" 2>&1 | grep -v "remote:"; then
        echo "ERROR: Failed to push git history" >&2
        cd - >/dev/null
        return 1
    fi
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: Successfully pushed to main branch" >&2
    fi
    
    cd - >/dev/null
    return 0
}