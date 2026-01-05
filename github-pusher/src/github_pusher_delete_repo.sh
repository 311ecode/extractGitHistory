#!/usr/bin/env bash
github_pusher_delete_repo() {
  local owner="$1"
  local repo_name="$2"
  local github_token="$3"
  local debug="${4:-false}"

  if [[ $debug == "true" ]]; then
    echo "DEBUG: Deleting repository: $owner/$repo_name" >&2
  fi

  curl -s -X DELETE \
    -H "Authorization: token $github_token" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/$owner/$repo_name" >/dev/null

  return 0
}
