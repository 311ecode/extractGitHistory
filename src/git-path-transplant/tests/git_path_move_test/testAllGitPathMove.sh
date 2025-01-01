#!/usr/bin/env bash
testAllGitPathMove() {
  export LC_NUMERIC=C
  local debug="${DEBUG:-}"

  OLDPWD="$PWD"

  local test_functions=(
    # Basic Functional Tests
    "testFileLevelTransplant"
    "testDeepIntraRepoMove"
    "testFullIntraRepoMove"
    "testRelativeUpwardMove"
    "testUnicodePathMove"
    "testHistoryCopy"
    "testRecursiveHistoryCopy"
    
    # Advanced Logic Tests (Smart Permutations)
    "testRelativeUpwardMoveWithCleanse"
    "testRelativeUpwardCopy"

    # Safety & Integrity Tests
    "testDirtyWorktreeIsolation"
    "testTransplantSafety"
    "testInterRepoMoveSafety"
    "testGitCleanseIntegration"
    
    # Mechanics & Parity Tests
    "testRegistrationLifecycle"
    "testShadingBypass"
    "testRebaseTransplant"
    "testHistoryParityMagic"
    "testHashParityRoundTrip"
    "testComplexHistoryPreservation"
    
    # Hook Tests
    "testCleanseHookFailure"
    "testCleanseHookParity"
  )
  
  local ignored_tests=()
  bashTestRunner test_functions ignored_tests
  cd "$OLDPWD"
}
