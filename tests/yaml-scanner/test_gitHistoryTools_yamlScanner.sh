#!/usr/bin/env bash
test_gitHistoryTools_yamlScanner() {
    export LC_NUMERIC=C
    
    # Test registry
    local test_functions=(
        "test_yamlScanner_directRepoName"
        "test_yamlScanner_pathBased"
        "test_yamlScanner_missingFields"
    )
    
    local ignored_tests=()
    
    bashTestRunner test_functions ignored_tests
    return $?
}