#!/usr/bin/env bash
# Date: 2026-03-04

test_gitHistoryTools_githubSyncWorkflow2() {
  export LC_NUMERIC=C

  local test_functions=(
    "test_githubSyncWorkflow2_discovery"
    "test_githubSyncWorkflow2_packagesh_hook"
    "test_githubSyncWorkflow2_integration"
  )

  local ignored_tests=()

  bashTestRunner test_functions ignored_tests
  return $?
}
