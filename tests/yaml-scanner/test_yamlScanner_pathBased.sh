#!/usr/bin/env bash
test_yamlScanner_pathBased() {
    echo "Testing path-based repo_name derivation"
    
    local test_dir=$(mktemp -d)
    local yaml_file="$test_dir/.github-sync.yaml"
    
    cat > "$yaml_file" <<'EOF'
github_user: testuser
path: /home/user/projects/my-awesome-repo
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
    
    local repo_name
    repo_name=$(echo "$output" | jq -r '.repo_name')
    
    if [[ "$repo_name" != "my-awesome-repo" ]]; then
        echo "ERROR: Expected repo_name 'my-awesome-repo', got '$repo_name'"
        return 1
    fi
    
    echo "SUCCESS: Path-based repo_name derivation works"
    return 0
}