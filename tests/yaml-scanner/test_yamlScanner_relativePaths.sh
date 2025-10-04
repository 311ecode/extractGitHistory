#!/usr/bin/env bash
test_yamlScanner_relativePaths() {
    echo "Testing relative path resolution"
    
    local test_dir=$(mktemp -d)
    
    # Create directory structure
    mkdir -p "$test_dir/projects/subdir1"
    mkdir -p "$test_dir/projects/subdir2"
    
    local yaml_file="$test_dir/.github-sync.yaml"
    
    cat > "$yaml_file" <<EOF
github_user: testuser

projects:
  - path: ./projects/subdir1
    repo_name: relative-with-dot
  - path: projects/subdir2
    repo_name: relative-without-dot
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
    
    # Verify first project (./projects/subdir1)
    local path1
    path1=$(echo "$output" | jq -r '.[0].path')
    local expected_path1="$test_dir/projects/subdir1"
    
    if [[ "$path1" != "$expected_path1" ]]; then
        echo "ERROR: First project path incorrect"
        echo "Expected: $expected_path1"
        echo "Got: $path1"
        rm -rf "$test_dir"
        return 1
    fi
    
    local repo1
    repo1=$(echo "$output" | jq -r '.[0].repo_name')
    if [[ "$repo1" != "relative-with-dot" ]]; then
        echo "ERROR: First project repo_name incorrect: $repo1"
        rm -rf "$test_dir"
        return 1
    fi
    
    # Verify second project (projects/subdir2)
    local path2
    path2=$(echo "$output" | jq -r '.[1].path')
    local expected_path2="$test_dir/projects/subdir2"
    
    if [[ "$path2" != "$expected_path2" ]]; then
        echo "ERROR: Second project path incorrect"
        echo "Expected: $expected_path2"
        echo "Got: $path2"
        rm -rf "$test_dir"
        return 1
    fi
    
    local repo2
    repo2=$(echo "$output" | jq -r '.[1].repo_name')
    if [[ "$repo2" != "relative-without-dot" ]]; then
        echo "ERROR: Second project repo_name incorrect: $repo2"
        rm -rf "$test_dir"
        return 1
    fi
    
    # Cleanup
    rm -rf "$test_dir"
    
    echo "SUCCESS: Relative path resolution works"
    return 0
}