#!/usr/bin/env bash

test_environment_validation() {
  echo "🧪 Testing environment variable validation"

  # 1. Define internal defaults for restoration if env is currently empty
  local DEFAULT_TEST_ORG='311ecode'
  local DEFAULT_TEST_TOKEN='ghp_Kw...'

  # 2. Save current state (using defaults if env is currently empty)
  local saved_token="${GITHUB_TOKEN:-}"
  local saved_test_token="${GITHUB_TEST_TOKEN:-$DEFAULT_TEST_TOKEN}"
  local saved_user="${GITHUB_USER:-}"
  local saved_test_org="${GITHUB_TEST_ORG:-$DEFAULT_TEST_ORG}"

  # 3. Perform the "Missing Credentials" Test
  # We unset everything to ensure the github_pusher guard clauses trigger
  unset GITHUB_TOKEN GITHUB_TEST_TOKEN GITHUB_USER GITHUB_TEST_ORG

  local output
  # This call SHOULD now trigger the "ERROR: GITHUB_TOKEN..." message
  # because we moved the guard clause to the top of github_pusher.sh
  output=$(github_pusher "./non_existent_meta.json" 2>&1)

  # 4. Restore original environment immediately
  # This ensures subsequent tests have the credentials they need
  export GITHUB_TOKEN="$saved_token"
  export GITHUB_TEST_TOKEN="$saved_test_token"
  export GITHUB_USER="$saved_user"
  export GITHUB_TEST_ORG="$saved_test_org"

  # 5. Validate the error message
  if echo "$output" | grep -q "ERROR: GITHUB_TOKEN"; then
    echo "✅ SUCCESS: Missing credentials caught correctly"
    return 0
  else
    echo "❌ ERROR: Failed to catch missing GITHUB_TOKEN"
    echo "Output was: $output"
    return 1
  fi
}
