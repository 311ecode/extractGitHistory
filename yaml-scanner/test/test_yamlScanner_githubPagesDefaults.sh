#!/usr/bin/env bash
test_yamlScanner_githubPagesDefaults() {
    echo "Testing GitHub Pages default values"
    
    local test_dir=$(mktemp -d)
    local yaml_file="$test_dir/.github-sync.yaml"
    
    # Create the actual directory so the existence check passes
    mkdir -p "$test_dir/repo1"
    
    # Create config with no Pages settings (should use defaults)
    cat > "$yaml_file" <<EOF
github_user: testuser

projects:
  - path: $test_dir/repo1
    repo_name: test-repo-1
EOF
    
    local output
    output=$(yaml_scanner "$yaml_file" 2>/dev/null)
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        echo "ERROR: yaml_scanner failed"
        # Print actual error to help debugging if it fails again
        yaml_scanner "$yaml_file" 2>&1
        rm -rf "$test_dir"
        return 1
    fi
    
    # Verify default githubPages is "false"
    local githubPages
    githubPages=$(echo "$output" | jq -r '.[0].githubPages')
    if [[ "$githubPages" != "false" ]]; then
        echo "ERROR: Expected githubPages='false' by default, got: $githubPages"
        rm -rf "$test_dir"
        return 1
    fi
    
    # Verify default branch is "main"
    local branch
    branch=$(echo "$output" | jq -r '.[0].githubPagesBranch')
    if [[ "$branch" != "main" ]]; then
        echo "ERROR: Expected githubPagesBranch='main' by default, got: $branch"
        rm -rf "$test_dir"
        return 1
    fi
    
    # Verify default path is "/"
    local path
    path=$(echo "$output" | jq -r '.[0].githubPagesPath')
    if [[ "$path" != "/" ]]; then
        echo "ERROR: Expected githubPagesPath='/' by default, got: $path"
        rm -rf "$test_dir"
        return 1
    fi
    
    rm -rf "$test_dir"
    echo "SUCCESS: GitHub Pages defaults work correctly"
    return 0
}
