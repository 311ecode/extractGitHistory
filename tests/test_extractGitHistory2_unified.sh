#!/usr/bin/env bash
test_extractGitHistory2_unified() {
  export LC_NUMERIC=C
  # Unified test registry combining both suites
  local test_functions=(
    # extract-git-path suite
    "test_gitHistoryTools_githubPusher"
    "test_gitHistoryTools_yamlScanner"

    "test-path-transplat-AllGitPathConvergeMerge"

    "testGitTransplantWorkflow"

    "test_github_pusher_all"

    "test-git-path-atomic-sync-suite"

  )
  local ignored_tests=()
  bashTestRunner test_functions ignored_tests
  return $?
}
