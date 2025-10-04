#!/usr/bin/env bash
test_gitHistoryTools_yamlScanner() {
    export LC_NUMERIC=C
    
    # Test registry
    local test_functions=(
        "test_yamlScanner_multipleProjects"
        "test_yamlScanner_emptyProjects"
        "test_yamlScanner_jsonOutput"
        "test_yamlScanner_relativePaths"
        "test_yamlScanner_mixedPaths"
        "test_yamlScanner_invalidRelativePath"
    )
    
    local ignored_tests=()
    
    bashTestRunner test_functions ignored_tests
    return $?
}