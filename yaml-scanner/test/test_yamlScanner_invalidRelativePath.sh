#!/usr/bin/env bash
test_yamlScanner_invalidRelativePath() {
    echo "Testing error handling for invalid relative path"
    
    local test_dir=$(mktemp -d)
    local yaml_file="$test_dir/.github-sync.yaml"
    
    # Define a path that definitely does not exist
    cat > "$yaml_file" <<EOF
github_user: testuser

projects:
  - path: ./nonexistent-directory
    repo_name: invalid-path
EOF
    
    # Execute scanner - we expect an error (non-zero exit code)
    local output
    output=$(yaml_scanner "$yaml_file" 2>&1)
    local exit_code=$?
    
    rm -rf "$test_dir"
    
    if [[ $exit_code -eq 0 ]]; then
        echo "ERROR: Should fail for nonexistent relative path (got exit code 0)"
        return 1
    fi
    
    # The scanner now uses a generic "Path does not exist" message
    if ! echo "$output" | grep -q "Path does not exist"; then
        echo "ERROR: Missing expected error message ('Path does not exist')"
        echo "Actual output was:"
        echo "$output"
        return 1
    fi
    
    echo "SUCCESS: Invalid relative path error handling works"
    return 0
}
