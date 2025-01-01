#!/usr/bin/env bash

testAllGitPathMergeMany() {
  export LC_NUMERIC=C
  local debug="${DEBUG:-}"

  OLDPWD="$PWD"

  local test_functions=(
    "testMultiPathMerge"
    "testMultiPathMergeRollback"
  )
  local ignored_tests=()
  
  bashTestRunner test_functions ignored_tests
  
  cd "$OLDPWD"
}
