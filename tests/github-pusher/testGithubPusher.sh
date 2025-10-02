#!/usr/bin/env bash
testGithubPusher() {
    export LC_NUMERIC=C
    
    # Test registry
    local test_functions=(
        "testGithubPusher_MetaJsonParsing"
        "testGithubPusher_RepoNameGeneration"
        "testGithubPusher_DryRun"
        "testGithubPusher_CreateAndCleanup"
        "testGithubPusher_AlreadyExists"
    )
    
    local ignored_tests=()
    
    bashTestRunner test_functions ignored_tests
    return $?
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    testGithubPusher
fi