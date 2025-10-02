#!/usr/bin/env bash
testGithubPusher_RepoNameGeneration() {
    echo "Testing repository name generation"
    
    local test_dir=$(mktemp -d)
    
    # Test case 1: nested path
    local meta_file="$test_dir/meta1.json"
    cat > "$meta_file" <<'EOF'
{
  "original_path": "/home/user/project/src/components",
  "original_repo_root": "/home/user/project",
  "relative_path": "src/components",
  "extracted_repo_path": "/tmp/extract_123/repo",
  "extraction_timestamp": "2025-01-15T10:00:00Z",
  "commit_mappings": {}
}
EOF
    
    local repo_name
    repo_name=$(github_pusher_generate_repo_name "$meta_file" "false")
    
    if [[ "$repo_name" != "components" ]]; then
        echo "ERROR: Expected 'components', got '$repo_name'"
        rm -rf "$test_dir"
        return 1
    fi
    
    # Test case 2: root path (.)
    meta_file="$test_dir/meta2.json"
    cat > "$meta_file" <<'EOF'
{
  "original_path": "/home/user/project",
  "original_repo_root": "/home/user/project",
  "relative_path": ".",
  "extracted_repo_path": "/tmp/extract_123/repo",
  "extraction_timestamp": "2025-01-15T10:00:00Z",
  "commit_mappings": {}
}
EOF
    
    repo_name=$(github_pusher_generate_repo_name "$meta_file" "false")
    
    if [[ "$repo_name" != "project" ]]; then
        echo "ERROR: Expected 'project', got '$repo_name'"
        rm -rf "$test_dir"
        return 1
    fi
    
    # Cleanup
    rm -rf "$test_dir"
    
    echo "SUCCESS: Repository name generation works"
    return 0
}