#!/usr/bin/env bash
github_pusher_check_repo_exists() {
  local owner="$1"
  local repo_name="$2"
  local github_token="$3"
  local debug="${4:-false}"

  if [[ $debug == "true" ]]; then
    echo "DEBUG: Checking if repo exists: $owner/$repo_name" >&2
  fi

  local response
  response=$(curl -s -H "Authorization: token $github_token" \
    "https://api.github.com/repos/$owner/$repo_name")

  if echo "$response" | jq -e '.id' >/dev/null 2>&1; then
    if [[ $debug == "true" ]]; then
      echo "DEBUG: Repository exists" >&2
    fi
    return 0
  else
    if [[ $debug == "true" ]]; then
      echo "DEBUG: Repository does not exist" >&2
    fi
    return 1
  fi
}
