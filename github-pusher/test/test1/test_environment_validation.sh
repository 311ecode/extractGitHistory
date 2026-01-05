#!/usr/bin/env bash
test_environment_validation() {
  echo "🧪 Testing environment variable validation"

  # 1. Save current state to restore later
  local saved_token="${GITHUB_TOKEN:-}"
  local saved_test_token="${GITHUB_TEST_TOKEN:-}"
  local saved_user="${GITHUB_USER:-}"
  local saved_test_org="${GITHUB_TEST_ORG:-}"

  # 2. Unset all potential credential variables
  unset GITHUB_TOKEN GITHUB_TEST_TOKEN GITHUB_USER GITHUB_TEST_ORG

  # 3. Run the pusher and capture stderr
  local output
  output=$(github_pusher "./non_existent_meta.json" 2>&1)

  # 4. Restore original environment immediately
  [[ -n $saved_token ]] && export GITHUB_TOKEN="$saved_token"
  [[ -n $saved_test_token ]] && export GITHUB_TEST_TOKEN="$saved_test_token"
  [[ -n $saved_user ]] && export GITHUB_USER="$saved_user"
  [[ -n $saved_test_org ]] && export GITHUB_TEST_ORG="$saved_test_org"

  # 5. Validate the error message exists
  if echo "$output" | grep -q "ERROR: GITHUB_TOKEN"; then
    echo "✅ SUCCESS: Missing credentials caught correctly"
    return 0
  else
    echo "❌ ERROR: Failed to catch missing GITHUB_TOKEN"
    echo "Output was: $output"
    return 1
  fi
}
