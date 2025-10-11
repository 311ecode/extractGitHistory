#!/usr/bin/env bash
test_gitHistoryTools_githubSyncWorkflow() {
    export LC_NUMERIC=C
    
    local test_functions=(
        "test_githubSyncWorkflow_integration"
        "test_githubSyncWorkflow_withPages"
    )
    
    local ignored_tests=()
    
    bashTestRunner test_functions ignored_tests
    return $?
}