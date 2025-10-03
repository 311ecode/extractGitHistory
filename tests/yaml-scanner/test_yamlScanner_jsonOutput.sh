#!/usr/bin/env bash
test_yamlScanner_jsonOutput() {
    echo "Testing JSON output to file"
    
    local test_dir=$(mktemp -d)
    local yaml_file="$test_dir/.github-sync.yaml"
    local json_output="$test_dir/output/projects.json"
    
    cat > "$yaml_file" <<EOF
github_user: testuser
json_output: $json_output

projects:
  - path: /home/user/projects/repo1
    repo_name: test-repo-1
  - path: /home/user/projects/repo2
EOF
    
    cd "$test_dir"
    local stderr_output
    stderr_output=$(yaml_scanner "$yaml_file" 2>&1 >/dev/null)
    local exit_code=$?
    
    cd - >/dev/null
    
    if [[ $exit_code -ne 0 ]]; then
        echo "ERROR: yaml_scanner failed"
        echo "$stderr_output"
        rm -rf "$test_dir"
        return 1
    fi
    
    # Verify file was created
    if [[ ! -f "$json_output" ]]; then
        echo "ERROR: JSON output file not created at $json_output"
        rm -rf "$test_dir"
        return 1
    fi
    
    # Verify stderr message
    if ! echo "$stderr_output" | grep -q "JSON output saved to: $json_output"; then
        echo "ERROR: Missing success message in stderr"
        echo "$stderr_output"
        rm -rf "$test_dir"
        return 1
    fi
    
    # Verify JSON content
    local user1
    user1=$(jq -r '.[0].github_user' "$json_output")
    if [[ "$user1" != "testuser" ]]; then
        echo "ERROR: Incorrect github_user in saved JSON: $user1"
        rm -rf "$test_dir"
        return 1
    fi
    
    local repo1
    repo1=$(jq -r '.[0].repo_name' "$json_output")
    if [[ "$repo1" != "test-repo-1" ]]; then
        echo "ERROR: Incorrect repo_name in saved JSON: $repo1"
        rm -rf "$test_dir"
        return 1
    fi
    
    # Verify second project (derived repo_name)
    local repo2
    repo2=$(jq -r '.[1].repo_name' "$json_output")
    if [[ "$repo2" != "repo2" ]]; then
        echo "ERROR: Derived repo_name incorrect: $repo2"
        rm -rf "$test_dir"
        return 1
    fi
    
    rm -rf "$test_dir"
    echo "SUCCESS: JSON output to file works"
    return 0
}