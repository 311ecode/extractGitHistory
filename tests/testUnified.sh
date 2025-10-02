#!/usr/bin/env bash
testUnified() {
  export LC_NUMERIC=C
  # Unified test registry combining both suites
  local test_functions=(
    # extract-git-path suite
    "testExtractGitPath"
    "testGithubPusher"
  )
  local ignored_tests=()
  bashTestRunner test_functions ignored_tests
  return $?
}
# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  testUnified
fi