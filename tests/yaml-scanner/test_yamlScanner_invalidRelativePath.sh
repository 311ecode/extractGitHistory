#!/usr/bin/env bash
test_yamlScanner_invalidRelativePath() {
    echo "Testing error handling for invalid relative path"
    
    local test_dir=$(mktemp -d)
    local yaml_file="$test_dir/.github-sync.yaml"
    
    cat > "$yaml_file" <<EOF
github_user: testuser

projects:
  - path: ./nonexistent-directory
    repo_name: invalid-path
EOF
    
    if [[ -n "${DEBUG:-}" ]]; then
        echo "DEBUG: Test directory: $test_dir" >&2
        echo "DEBUG: YAML file contents:" >&2
        cat "$yaml_file" >&2
    fi
    
    cd "$test_dir"
    local output
    output=$(yaml_scanner "$yaml_file" 2>&1)
    local exit_code=$?
    
    if [[ -n "${DEBUG:-}" ]]; then
        echo "DEBUG: Scanner output:" >&2
        echo "$output" >&2
        echo "DEBUG: Exit code: $exit_code" >&2
    fi
    
    cd - >/dev/null
    rm -rf "$test_dir"
    
    if [[ $exit_code -eq 0 ]]; then
        echo "ERROR: Should fail for nonexistent relative path (got exit code 0)"
        echo "Output was:"
        echo "$output"
        return 1
    fi
    
    if ! echo "$output" | grep -q "Cannot resolve relative path"; then
        echo "ERROR: Missing expected error message"
        echo "Output was:"
        echo "$output"
        return 1
    fi
    
    echo "SUCCESS: Invalid relative path error handling works"
    return 0
}