#!/usr/bin/env bash
testAllGitPathMove() {
  export LC_NUMERIC=C
  local debug="${DEBUG:-}"

  OLDPWD="$PWD"

  local test_functions=(
    "testFullIntraRepoMove" 
    "testInterRepoMoveSafety" 
    "testDeepIntraRepoMove" 
    "testRelativeUpwardMove"
    "testShadingBypass"
    "testRegistrationLifecycle"
    "testHistoryCopy"
    "testRecursiveHistoryCopy"
    "testHistoryParityMagic"
  )
  local ignored_tests=()
  bashTestRunner test_functions ignored_tests
  cd "$OLDPWD"
}
