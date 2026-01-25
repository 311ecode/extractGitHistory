#!/usr/bin/env bash
test_github_pusher_all() {
  export LC_NUMERIC=C
  # Unified test registry combining both suites
  local test_functions=(
    # extract-git-path suite
    "test_gitHistoryTools_githubPusher"
    "test_github_pusher"

  )
  local ignored_tests=()
  bashTestRunner test_functions ignored_tests
  return $?
}
