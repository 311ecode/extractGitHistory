#!/usr/bin/env bash
github_pusher_test_cleanup() {
  local github_token="${GITHUB_TEST_TOKEN:-${GITHUB_TOKEN}}"
  local github_user="${GITHUB_TEST_ORG:-${GITHUB_USER}}"
  local debug="${DEBUG:-false}"

  if [[ -z $github_token ]] || [[ -z $github_user ]]; then
    echo "Cleanup skipped: Credentials not set." >&2
    return 0
  fi

  echo "Cleaning up leftover test repositories for: $github_user" >&2

  # Fetch all repositories for the user/org
  # We use per_page=100 to catch as many as possible in one go
  local repos
  repos=$(curl -s -H "Authorization: token $github_token" \
    "https://api.github.com/users/$github_user/repos?per_page=100")

  # If the above returns empty, try the org endpoint
  if [[ $(echo "$repos" | jq 'type == "array"') != "true" ]]; then
    repos=$(curl -s -H "Authorization: token $github_token" \
      "https://api.github.com/orgs/$github_user/repos?per_page=100")
  fi

  # Filter for repos starting with our test prefix
  local test_repos
  test_repos=$(echo "$repos" | jq -r '.[] | .name | select(test("^src-test-"))')

  if [[ -z $test_repos ]]; then
    echo "No leftover test repositories found." >&2
    return 0
  fi

  for repo in $test_repos; do
    echo "Removing leftover test repo: $repo" >&2
    github_pusher_delete_repo "$github_user" "$repo" "$github_token" "$debug"
  done

  echo "Cleanup complete." >&2
}
