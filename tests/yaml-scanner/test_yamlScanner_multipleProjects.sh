#!/usr/bin/env bash
test_yamlScanner_multipleProjects() {
    echo "Testing multiple projects extraction"
    
    local test_dir=$(mktemp -d)
    local yaml_file="$test_dir/.github-sync.yaml"
    
    cat > "$yaml_file" <<'EOF'
github_user: testuser

projects:
  - path: /home/user/projects/repo1
    repo_name: custom-repo-1
  - path: /home/user/projects/repo2
  - path: /path/to/another-project
    repo_name: special-name
EOF
    
    cd "$test_dir"
    local output
    output=$(yaml_scanner "$yaml_file" 2>&1)
    local exit_code=$?
    
    cd - >/dev/null
    rm -rf "$test_dir"
    
    if [[ $exit_code -ne 0 ]]; then
        echo "ERROR: yaml_scanner failed"
        echo "$output"
        return 1
    fi
    
    # Verify all projects have the same github_user
    local user1
    user1=$(echo "$output" | jq -r '.[0].github_user')
    if [[ "$user1" != "testuser" ]]; then
        echo "ERROR: First project github_user incorrect: $user1"
        return 1
    fi
    
    local user2
    user2=$(echo "$output" | jq -r '.[1].github_user')
    if [[ "$user2" != "testuser" ]]; then
        echo "ERROR: Second project github_user incorrect: $user2"
        return 1
    fi
    
    local user3
    user3=$(echo "$output" | jq -r '.[2].github_user')
    if [[ "$user3" != "testuser" ]]; then
        echo "ERROR: Third project github_user incorrect: $user3"
        return 1
    fi
    
    # Verify first project repo_name
    local repo1
    repo1=$(echo "$output" | jq -r '.[0].repo_name')
    if [[ "$repo1" != "custom-repo-1" ]]; then
        echo "ERROR: First project repo_name incorrect: $repo1"
        return 1
    fi
    
    # Verify second project (derived repo_name)
    local repo2
    repo2=$(echo "$output" | jq -r '.[1].repo_name')
    if [[ "$repo2" != "repo2" ]]; then
        echo "ERROR: Second project repo_name should be derived 'repo2': $repo2"
        return 1
    fi
    
    # Verify third project
    local repo3
    repo3=$(echo "$output" | jq -r '.[2].repo_name')
    if [[ "$repo3" != "special-name" ]]; then
        echo "ERROR: Third project repo_name incorrect: $repo3"
        return 1
    fi
    
    echo "SUCCESS: Multiple projects extraction works"
    return 0
}