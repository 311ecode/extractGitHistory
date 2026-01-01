#!/usr/bin/env bash

# @file extract_git_path_test.sh
# @brief Test suite for Git Path Extractor
# @description Validates repository detection, path extraction, and commit mapping logic.

test_extract_git_path() {
  export LC_NUMERIC=C


  # Test function registry 📋
  local test_functions=(
    "test_argument_validation"
    "test_outside_git_repo"
    "test_successful_extraction"
    "test_commit_mapping_logic"
  )

  local ignored_tests=()

  bashTestRunner test_functions ignored_tests
  return $?
}

# Execute if run directly 🚀
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  test_extract_git_path
fi
