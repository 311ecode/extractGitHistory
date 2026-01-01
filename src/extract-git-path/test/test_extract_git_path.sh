#!/usr/bin/env bash
test_extract_git_path() {
  export LC_NUMERIC=C

  # Test function registry 📋
  local test_functions=(
    "test_argument_validation"
    "test_outside_git_repo"
    "test_successful_extraction"
    "test_commit_mapping_logic"
    "test_absolute_path_support"
    "test_relative_parent_paths"
  )

  local ignored_tests=()

  bashTestRunner test_functions ignored_tests
  return $?
}