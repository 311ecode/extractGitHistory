#!/usr/bin/env bash
test_gitHistoryTools_unified() {
  export LC_NUMERIC=C
  # Unified test registry combining both suites
  local test_functions=(
    # extract-git-path suite
    "test_gitHistoryTools_githubPusher"
    "test_gitHistoryTools_yamlScanner"

    "test_gitHistoryTools_extractGitPath"
    "test_gitHistoryTools_extractGitPath2"
    "test_extract_git_path"

    "testAllGitPathConvergeMerge"

    "testGitTransplantWorkflow"
    
  )
  local ignored_tests=()
  bashTestRunner test_functions ignored_tests
  return $?
}