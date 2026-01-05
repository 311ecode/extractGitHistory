#!/usr/bin/env bash
github_pusher_update_repo_visibility() {
  local owner="$1"
  local repo_name="$2"
  local private="$3" # Expected: "true" or "false"
  local github_token="$4"
  local debug="${5:-false}"

  if [[ $debug == "true" ]]; then
    echo "DEBUG: [VISIBILITY_PATCH] Target: $owner/$repo_name | Requested: $private" >&2
  fi

  # Force strict boolean conversion for the API
  local private_bool="true"
  [[ $private == "false" ]] && private_bool="false"

  local payload=$(jq -n --argjson private "$private_bool" '{private: $private}')

  if [[ $debug == "true" ]]; then
    echo "DEBUG: [API_PAYLOAD_PATCH] Payload: $payload" >&2
  fi

  local temp_response=$(mktemp)
  local http_code=$(curl -s -w "%{http_code}" -o "$temp_response" -X PATCH \
    -H "Authorization: token $github_token" \
    -H "Accept: application/vnd.github.v3+json" \
    -d "$payload" \
    "https://api.github.com/repos/$owner/$repo_name")

  if [[ $debug == "true" ]]; then
    echo "DEBUG: [API_RESPONSE_PATCH] HTTP $http_code" >&2
    jq '.' "$temp_response" 2>/dev/null || cat "$temp_response" >&2
  fi

  rm -f "$temp_response"
  [[ $http_code == "200" ]] && return 0 || return 1
}
