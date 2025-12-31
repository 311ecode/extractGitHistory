#!/usr/bin/env bash
testAllGitPathMove() {
  export LC_NUMERIC=C
  local debug="${DEBUG:-}"

  OLDPWD="$PWD"

  local test_functions=(
    # ... previous tests ...
    "testFileLevelTransplant"
    "testDirtyWorktreeIsolation" # <--- Added this
  )
  local ignored_tests=()
  bashTestRunner test_functions ignored_tests
  cd "$OLDPWD"
}
