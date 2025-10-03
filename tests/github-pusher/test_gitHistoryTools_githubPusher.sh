#!/usr/bin/env bash
test_gitHistoryTools_githubPusher() {
    export LC_NUMERIC=C
    
    # Test registry
    local test_functions=(
        "test_githubPusher_metaJsonParsing"
        "test_githubPusher_repoNameGeneration"
        "test_githubPusher_dryRun"
        "test_githubPusher_createAndCleanup"
        "test_githubPusher_alreadyExists"
        "test_githubPusher_updatesMetaJson"
        "test_githubPusher_readmeDescription"
    )
    
    local ignored_tests=()
    
    bashTestRunner test_functions ignored_tests
    return $?
}