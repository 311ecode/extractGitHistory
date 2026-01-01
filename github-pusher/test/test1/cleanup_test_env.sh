#!/usr/bin/env bash
cleanup_test_env() {
  echo "🧹 Cleaning up test artifacts..."
  # Clean up local temp files
  rm -rf /tmp/extract-git-path/* 2>/dev/null
  # Clean up GitHub test repos (using the atomic cleanup function)
  if [[ -n "$GITHUB_TEST_TOKEN" ]]; then
    cleanupGithubRepos --yes "gh-pusher-test-*"
  fi
}