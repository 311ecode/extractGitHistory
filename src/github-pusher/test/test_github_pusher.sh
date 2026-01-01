#!/usr/bin/env bash

# @file github_pusher_test.sh
# @brief Integration test suite for GitHub Pusher
# @description Uses real extraction metadata to test the pusher logic.

test_github_pusher() {
  export LC_NUMERIC=C
  
  # Ensure cleanup happens even if tests fail
  trap 'cleanup_test_env' EXIT

  local test_functions=(
    "test_environment_validation"
    "test_full_integration_dry_run"
    "test_name_generation_from_real_meta"
    "test_description_extraction_from_real_readme"
  )

  local ignored_tests=()

  # Execute the runner
  bashTestRunner test_functions ignored_tests
  return $?
}








