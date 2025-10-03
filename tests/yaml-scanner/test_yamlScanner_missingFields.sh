#!/usr/bin/env bash
test_yamlScanner_missingFields() {
    echo "Testing error handling for missing fields"
    
    local test_dir=$(mktemp -d)
    local yaml_file="$test_dir/.github-sync.yaml"
    
    # Test missing github_user
    cat > "$yaml_file" <<'EOF'
repo_name: test-repo
EOF
    
    cd "$test_dir"
    local output
    output=$(yaml_scanner "$yaml_file" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        echo "ERROR: Should fail when github_user missing"
        cd - >/dev/null
        rm -rf "$test_dir"
        return 1
    fi
    
    if ! echo "$output" | grep -q "Could not extract github_user"; then
        echo "ERROR: Missing expected error message for github_user"
        cd - >/dev/null
        rm -rf "$test_dir"
        return 1
    fi
    
    # Test missing repo_name and path
    cat > "$yaml_file" <<'EOF'
github_user: testuser
EOF
    
    output=$(yaml_scanner "$yaml_file" 2>&1)
    exit_code=$?
    
    cd - >/dev/null
    rm -rf "$test_dir"
    
    if [[ $exit_code -eq 0 ]]; then
        echo "ERROR: Should fail when both repo_name and path missing"
        return 1
    fi
    
    if ! echo "$output" | grep -q "Could not extract repo_name or path"; then
        echo "ERROR: Missing expected error message for repo_name/path"
        return 1
    fi
    
    echo "SUCCESS: Missing field errors work correctly"
    return 0
}