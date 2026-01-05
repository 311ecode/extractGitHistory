#!/usr/bin/env bash
github_pusher() {
  command -v markdown-show-help-registration &>/dev/null && eval "$(markdown-show-help-registration --minimum-parameters 1)"

  local meta_file="$1"
  local dry_run="${2:-false}"
  local debug="${DEBUG:-false}"
  [[ $debug == "1" ]] && debug="true"

  local github_token="${GITHUB_TEST_TOKEN:-${GITHUB_TOKEN}}"
  local github_user="${GITHUB_TEST_ORG:-${GITHUB_USER}}"

  github_pusher_parse_meta_json "$meta_file" "$debug" || return 1
  local repo_name=$(github_pusher_generate_repo_name "$meta_file" "$debug")
  local extracted_repo_path=$(jq -r '.extracted_repo_path' "$meta_file")
  local description=$(github_pusher_get_description "$extracted_repo_path" "orig" "$debug")

  # Capture Visibility
  local raw_private=$(jq -r '.custom_private // "true"' "$meta_file")
  [[ $debug == "true" ]] && echo "DEBUG: [PAYLOAD_TRACE] Raw 'custom_private' from meta: '$raw_private'" >&2

  local private="true"
  if [[ $raw_private == "false" || $raw_private == "FALSE" ]]; then private="false"; fi

  if github_pusher_check_repo_exists "$github_user" "$repo_name" "$github_token" "$debug"; then
    github_pusher_update_repo_visibility "$github_user" "$repo_name" "$private" "$github_token" "$debug"
  else
    [[ $debug == "true" ]] && echo "DEBUG: [POST_PAYLOAD] constructor input: name=$repo_name, private=$private" >&2
    github_pusher_create_repo "$github_user" "$repo_name" "$description" "$private" "$github_token" "$debug" "$dry_run"
  fi

  # Push and Enable Pages logic...
  github_pusher_push_git_history "$extracted_repo_path" "$github_user" "$repo_name" "$github_token" "$debug" "$dry_run" "$meta_file"

  local githubPages=$(jq -r '.custom_githubPages // "false"' "$meta_file")
  if [[ $githubPages == "true" ]]; then
    local branch=$(jq -r '.custom_githubPagesBranch // "main"' "$meta_file")
    local path=$(jq -r '.custom_githubPagesPath // "/"' "$meta_file")
    github_pusher_enable_pages "$github_user" "$repo_name" "$branch" "$path" "$github_token" "$debug" "$extracted_repo_path"
  fi

  echo "https://github.com/$github_user/$repo_name"
}
