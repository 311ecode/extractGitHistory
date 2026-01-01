#!/usr/bin/env bash
test_yamlScanner_githubPagesCustom() {
    echo "Testing GitHub Pages custom settings"
    
    local test_dir=$(mktemp -d)
    local yaml_file="$test_dir/.github-sync.yaml"
    
    # Create config with custom Pages settings
    cat > "$yaml_file" <<'EOF'
github_user: testuser

projects:
  - path: /home/user/projects/website
    repo_name: my-site
    githubPages: true
    githubPagesBranch: gh-pages
    githubPagesPath: /docs
  - path: /home/user/projects/backend
    repo_name: api-server
    githubPages: false
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
    
    # Verify first project (Pages enabled with custom settings)
    local pages1
    pages1=$(echo "$output" | jq -r '.[0].githubPages')
    if [[ "$pages1" != "true" ]]; then
        echo "ERROR: Expected githubPages='true', got: $pages1"
        return 1
    fi
    
    local branch1
    branch1=$(echo "$output" | jq -r '.[0].githubPagesBranch')
    if [[ "$branch1" != "gh-pages" ]]; then
        echo "ERROR: Expected githubPagesBranch='gh-pages', got: $branch1"
        return 1
    fi
    
    local path1
    path1=$(echo "$output" | jq -r '.[0].githubPagesPath')
    if [[ "$path1" != "/docs" ]]; then
        echo "ERROR: Expected githubPagesPath='/docs', got: $path1"
        return 1
    fi
    
    # Verify second project (Pages explicitly disabled)
    local pages2
    pages2=$(echo "$output" | jq -r '.[1].githubPages')
    if [[ "$pages2" != "false" ]]; then
        echo "ERROR: Expected githubPages='false', got: $pages2"
        return 1
    fi
    
    # Should still have default branch/path even when disabled
    local branch2
    branch2=$(echo "$output" | jq -r '.[1].githubPagesBranch')
    if [[ "$branch2" != "main" ]]; then
        echo "ERROR: Expected default githubPagesBranch='main', got: $branch2"
        return 1
    fi
    
    local path2
    path2=$(echo "$output" | jq -r '.[1].githubPagesPath')
    if [[ "$path2" != "/" ]]; then
        echo "ERROR: Expected default githubPagesPath='/', got: $path2"
        return 1
    fi
    
    echo "SUCCESS: GitHub Pages custom settings work correctly"
    return 0
}