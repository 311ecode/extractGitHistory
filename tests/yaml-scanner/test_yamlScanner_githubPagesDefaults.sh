#!/usr/bin/env bash
test_yamlScanner_githubPagesDefaults() {
    echo "Testing GitHub Pages default values"
    
    local test_dir=$(mktemp -d)
    local yaml_file="$test_dir/.github-sync.yaml"
    
    # Create config with no Pages settings (should use defaults)
    cat > "$yaml_file" <<'EOF'
github_user: testuser

projects:
  - path: /home/user/projects/repo1
    repo_name: test-repo-1
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
    
    # Verify default githubPages is "false"
    local githubPages
    githubPages=$(echo "$output" | jq -r '.[0].githubPages')
    if [[ "$githubPages" != "false" ]]; then
        echo "ERROR: Expected githubPages='false' by default, got: $githubPages"
        return 1
    fi
    
    # Verify default branch is "main"
    local branch
    branch=$(echo "$output" | jq -r '.[0].githubPagesBranch')
    if [[ "$branch" != "main" ]]; then
        echo "ERROR: Expected githubPagesBranch='main' by default, got: $branch"
        return 1
    fi
    
    # Verify default path is "/"
    local path
    path=$(echo "$output" | jq -r '.[0].githubPagesPath')
    if [[ "$path" != "/" ]]; then
        echo "ERROR: Expected githubPagesPath='/' by default, got: $path"
        return 1
    fi
    
    echo "SUCCESS: GitHub Pages defaults work correctly"
    return 0
}