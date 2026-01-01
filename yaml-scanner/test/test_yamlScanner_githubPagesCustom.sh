#!/usr/bin/env bash
test_yamlScanner_githubPagesCustom() {
    echo "Testing GitHub Pages custom settings"
    
    local test_dir=$(mktemp -d)
    local yaml_file="$test_dir/.github-sync.yaml"
    
    # Create the actual directories so the scanner's existence check passes
    mkdir -p "$test_dir/website"
    mkdir -p "$test_dir/backend"
    
    # Create config with custom Pages settings
    cat > "$yaml_file" <<EOF
github_user: testuser

projects:
  - path: $test_dir/website
    repo_name: my-site
    githubPages: true
    githubPagesBranch: gh-pages
    githubPagesPath: /docs
  - path: $test_dir/backend
    repo_name: api-server
    githubPages: false
EOF
    
    local output
    output=$(yaml_scanner "$yaml_file" 2>/dev/null)
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        echo "ERROR: yaml_scanner failed"
        # Re-run with stderr visible for troubleshooting if needed
        yaml_scanner "$yaml_file" 2>&1
        rm -rf "$test_dir"
        return 1
    fi
    
    # Verify first project (Pages enabled with custom settings)
    local pages1
    pages1=$(echo "$output" | jq -r '.[0].githubPages')
    if [[ "$pages1" != "true" ]]; then
        echo "ERROR: Expected githubPages='true', got: $pages1"
        rm -rf "$test_dir"
        return 1
    fi
    
    local branch1
    branch1=$(echo "$output" | jq -r '.[0].githubPagesBranch')
    if [[ "$branch1" != "gh-pages" ]]; then
        echo "ERROR: Expected githubPagesBranch='gh-pages', got: $branch1"
        rm -rf "$test_dir"
        return 1
    fi
    
    local path1
    path1=$(echo "$output" | jq -r '.[0].githubPagesPath')
    if [[ "$path1" != "/docs" ]]; then
        echo "ERROR: Expected githubPagesPath='/docs', got: $path1"
        rm -rf "$test_dir"
        return 1
    fi
    
    # Verify second project (Pages explicitly disabled)
    local pages2
    pages2=$(echo "$output" | jq -r '.[1].githubPages')
    if [[ "$pages2" != "false" ]]; then
        echo "ERROR: Expected githubPages='false', got: $pages2"
        rm -rf "$test_dir"
        return 1
    fi
    
    rm -rf "$test_dir"
    echo "SUCCESS: GitHub Pages custom settings work correctly"
    return 0
}
