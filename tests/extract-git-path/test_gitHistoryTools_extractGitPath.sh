#!/usr/bin/env bash
test_gitHistoryTools_extractGitPath() {
  export LC_NUMERIC=C

  # Test registry
  local test_functions=(
    "test_extractGitPath_absolutePath"
    "test_extractGitPath_relativePath"
    "test_extractGitPath_pathNotInRepo"
    "test_extractGitPath_pathNeverTracked"
    "test_extractGitPath_historyFlattened"
    "test_extractGitPath_multipleCommits"
    "test_extractGitPath_repoRoot"
    "test_extractGitPath_commitMappings"
  )

  local ignored_tests=()

  bashTestRunner test_functions ignored_tests
  return $?
}