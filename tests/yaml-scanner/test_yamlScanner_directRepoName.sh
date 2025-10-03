#!/usr/bin/env bash
test_yamlScanner_directRepoName() {
    echo "Testing direct repo_name extraction"
    
    local test_dir=$(mktemp -d)
    local yaml_file="$test_dir/.github-sync.yaml"
    
    cat > "$yaml_file" <<'EOF'
github_user: testuser
repo_name: test-repository
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
    
    local github_user
    github_user=$(echo "$output" | jq -r '.github_user')
    
    if [[ "$github_user" != "testuser" ]]; then
        echo "ERROR: Expected github_user 'testuser', got '$github_user'"
        return 1
    fi
    
    local repo_name
    repo_name=$(echo "$output" | jq -r '.repo_name')
    
    if [[ "$repo_name" != "test-repository" ]]; then
        echo "ERROR: Expected repo_name 'test-repository', got '$repo_name'"
        return 1
    fi
    
    echo "SUCCESS: Direct repo_name extraction works"
    return 0
}