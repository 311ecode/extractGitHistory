#!/usr/bin/env bash
github_pusher_update_repo_description() {
  local owner="$1"
  local repo_name="$2"
  local description="$3"
  local github_token="$4"
  local debug="${5:-false}"

  if [[ $debug == "true" ]]; then
    echo "DEBUG: Updating repository description to: $description" >&2
  fi

  local payload
  payload=$(jq -n --arg desc "$description" '{description: $desc}')

  local response
  response=$(curl -s -X PATCH \
    -H "Authorization: token $github_token" \
    -H "Accept: application/vnd.github.v3+json" \
    -d "$payload" \
    "https://api.github.com/repos/$owner/$repo_name")

  if [[ $debug == "true" ]]; then
    echo "DEBUG: Update response:" >&2
    echo "$response" | jq '.' >&2
  fi

  return 0
}
