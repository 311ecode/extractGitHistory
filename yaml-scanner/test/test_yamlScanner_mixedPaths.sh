#!/usr/bin/env bash
test_yamlScanner_mixedPaths() {
    echo "Testing mixed absolute and relative paths"
    
    local test_dir=$(mktemp -d)
    mkdir -p "$test_dir/relative-project"
    
    local yaml_file="$test_dir/.github-sync.yaml"
    
    cat > "$yaml_file" <<EOF
github_user: testuser

projects:
  - path: /tmp
    repo_name: absolute-path
  - path: ./relative-project
    repo_name: relative-path
EOF
    
    cd "$test_dir"
    local output
    output=$(yaml_scanner "$yaml_file" 2>&1)
    local exit_code=$?
    
    cd - >/dev/null
    
    if [[ $exit_code -ne 0 ]]; then
        echo "ERROR: yaml_scanner failed"
        echo "$output"
        rm -rf "$test_dir"
        return 1
    fi
    
    # Verify absolute path unchanged
    local path1
    path1=$(echo "$output" | jq -r '.[0].path')
    if [[ "$path1" != "/tmp" ]]; then
        echo "ERROR: Absolute path was modified: $path1"
        rm -rf "$test_dir"
        return 1
    fi
    
    # Verify relative path resolved
    local path2
    path2=$(echo "$output" | jq -r '.[1].path')
    local expected_path2="$test_dir/relative-project"
    
    if [[ "$path2" != "$expected_path2" ]]; then
        echo "ERROR: Relative path not resolved correctly"
        echo "Expected: $expected_path2"
        echo "Got: $path2"
        rm -rf "$test_dir"
        return 1
    fi
    
    # Cleanup
    rm -rf "$test_dir"
    
    echo "SUCCESS: Mixed paths work correctly"
    return 0
}