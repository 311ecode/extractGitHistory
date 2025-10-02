#!/usr/bin/env bash
# Test suite for extract-git-path.sh


testExtractGitPath() {
  export LC_NUMERIC=C

  # Nested test functions
  

  

  

  

  

  

  

  # Test registry
  local test_functions=(
    "testAbsolutePath"
    "testRelativePath"
    "testPathNotInRepo"
    "testPathNeverTracked"
    "testHistoryFlattened"
    "testMultipleCommits"
    "testRepoRoot"
  )

  local ignored_tests=()

  bashTestRunner test_functions ignored_tests
  return $?
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  testExtractGitPath
fi