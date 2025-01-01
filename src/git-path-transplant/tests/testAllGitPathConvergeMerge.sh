#!/usr/bin/env bash

testAllGitPathConvergeMerge() {
  export LC_NUMERIC=C
  local debug="${DEBUG:-}"

  OLDPWD="$PWD"

  # Test functions organized by logical complexity:
  # 1. Basic Merging & Conflict Handling
  # 2. Multi-source (Triple) Convergence
  # 3. Content & History Verification
  # 4. Full-Cycle Sync (Converge -> Modify -> Distribute)
  # 5. Atomic Protection & Physical Restoration
  local test_functions=(
    "testConvergeMergeSuccess"
    "testConvergeMergeConflictHandling"
    "testConvergeMergeTripleSource"
    "testConvergeMergeFullSync"
    "testProjectConvergeSync"
    "testFullSyncCircle"
    "testAtomicSyncFailure"
    "testUltimateSync"

    # as an orphan we add it here as it is closely related
    "testGitTransplantWorkflow"
  )
  
  local ignored_tests=()
  
  # Execute the test runner
  bashTestRunner test_functions ignored_tests
  
  cd "$OLDPWD"
}
