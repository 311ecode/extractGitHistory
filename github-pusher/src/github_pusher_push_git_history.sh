#!/usr/bin/env bash
github_pusher_push_git_history() {
  local extracted_repo_path="$1"
  local owner="$2"
  local repo_name="$3"
  local github_token="$4"
  local debug="${5:-false}"
  local dry_run="${6:-false}"
  local meta_file="${7:-}"

  if [[ $dry_run == "true" ]]; then
    echo "[DRY RUN] Would push git history from: $extracted_repo_path" >&2
    return 0
  fi

  if [[ $debug == "true" ]]; then
    echo "DEBUG: Pushing git history to GitHub..." >&2
    echo "DEBUG: Source: $extracted_repo_path" >&2
    echo "DEBUG: Target: $owner/$repo_name" >&2
  fi

  if [[ ! -d $extracted_repo_path ]]; then
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

  if [[ $debug == "true" ]]; then
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

  # Get current branch name
  local branch_name
  branch_name=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "master")

  # Determine if we should force push
  local force_flag=""
  local forcePush="true" # Default to true

  # Try to read forcePush from meta.json if provided
  if [[ -n $meta_file ]] && [[ -f $meta_file ]]; then
    local custom_forcePush
    custom_forcePush=$(jq -r '.custom_forcePush // "true"' "$meta_file" 2>/dev/null)

    if [[ -n $custom_forcePush ]] && [[ $custom_forcePush != "null" ]]; then
      forcePush="$custom_forcePush"
    fi

    if [[ $debug == "true" ]]; then
      echo "DEBUG: forcePush setting from meta.json: $forcePush" >&2
    fi
  fi

  # Normalize forcePush value
  if [[ $forcePush == "false" ]] || [[ $forcePush == "False" ]] || [[ $forcePush == "FALSE" ]]; then
    force_flag=""
    if [[ $debug == "true" ]]; then
      echo "DEBUG: Force push disabled - will fail if remote has diverged" >&2
    fi
  else
    force_flag="--force"
    if [[ $debug == "true" ]]; then
      echo "DEBUG: Force push enabled - will overwrite remote changes" >&2
    fi
  fi

  if [[ $debug == "true" ]]; then
    echo "DEBUG: Pushing to origin with flags: ${force_flag:-<none>}" >&2
  fi

  # Capture both stdout and stderr
  local push_output
  local push_exit_code

  push_output=$(git push $force_flag -u origin "${branch_name}:main" 2>&1)
  push_exit_code=$?

  # Filter out GitHub's remote messages but keep error messages
  local filtered_output
  filtered_output=$(echo "$push_output" | grep -v "^remote:" | grep -v "^$")

  if [[ $debug == "true" ]]; then
    echo "DEBUG: Push exit code: $push_exit_code" >&2
    if [[ -n $filtered_output ]]; then
      echo "DEBUG: Push output:" >&2
      echo "$filtered_output" >&2
    fi
  fi

  # Check for push failure
  if [[ $push_exit_code -ne 0 ]]; then
    echo "ERROR: Failed to push git history" >&2

    # Show filtered output to user
    if [[ -n $filtered_output ]]; then
      echo "$filtered_output" >&2
    fi

    # Check if it's a force-push-needed scenario
    if echo "$push_output" | grep -q "rejected.*fetch first\|rejected.*non-fast-forward"; then
      if [[ $forcePush == "false" ]]; then
        echo "ERROR: Remote has diverged and forcePush is disabled" >&2
        echo "ERROR: Set forcePush: true in your YAML config to overwrite remote changes" >&2
      else
        echo "ERROR: Push failed even though forcePush is enabled" >&2
      fi
    fi

    cd - >/dev/null
    return 1
  fi

  if [[ $debug == "true" ]]; then
    echo "DEBUG: Successfully pushed to main branch" >&2
  fi

  cd - >/dev/null
  return 0
}
