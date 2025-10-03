#!/usr/bin/env bash
test_gitHistoryTools_yamlScanner() {
    export LC_NUMERIC=C
    
    # Test registry
    local test_functions=(
        "test_yamlScanner_multipleProjects"
        "test_yamlScanner_emptyProjects"
    )
    
    local ignored_tests=()
    
    bashTestRunner test_functions ignored_tests
    return $?
}