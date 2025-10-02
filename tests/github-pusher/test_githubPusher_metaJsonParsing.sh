#!/usr/bin/env bash
test_githubPusher_metaJsonParsing() {
    echo "Testing meta.json parsing"
    
    # Create test meta.json
    local test_dir=$(mktemp -d)
    local meta_file="$test_dir/extract-git-path-meta.json"
    
    cat > "$meta_file" <<'EOF'
{
  "original_path": "/home/user/project/src/components",
  "original_repo_root": "/home/user/project",
  "relative_path": "src/components",
  "extracted_repo_path": "/tmp/extract_123/repo",
  "extraction_timestamp": "2025-01-15T10:00:00Z",
  "commit_mappings": {
    "abc123": "def456"
  }
}
EOF
    
    # Test parsing
    if ! github_pusher_parse_meta_json "$meta_file" "false"; then
        echo "ERROR: Meta JSON parsing failed"
        rm -rf "$test_dir"
        return 1
    fi
    
    # Cleanup
    rm -rf "$test_dir"
    
    echo "SUCCESS: Meta JSON parsing works"
    return 0
}