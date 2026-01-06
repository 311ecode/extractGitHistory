#!/usr/bin/env bash
test_gitHistoryTools_githubPusher() {
  export LC_NUMERIC=C

  # Test registry
  local test_functions=(
    "test_githubPusher_metaJsonParsing"
    "test_githubPusher_repoNameGeneration"
    "test_githubPusher_dryRun"
    "test_githubPusher_createAndCleanup"
    "test_githubPusher_alreadyExists"
    "test_githubPusher_updatesMetaJson"
    "test_githubPusher_readmeDescription"
    "test_githubPusher_updateVisibility"
    "test_githubPusher_enablePages"
    "test_githubPusher_pagesPathValidation"
    "test_githubPusher_pagesCustomPath"
  )

  local ignored_tests=(
    test_githubPusher_updateVisibility  # Flaky due to GitHub API timings sometimes works, sometimes fails
  )

  # Run tests
  bashTestRunner test_functions ignored_tests
  local result=$?

  # Always attempt a global cleanup of test repos after the suite finishes
  github_pusher_test_cleanup

  return $result
}
