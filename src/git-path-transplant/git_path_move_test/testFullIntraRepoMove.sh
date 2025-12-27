#!/usr/bin/env bash
testFullIntraRepoMove() {
    echo "🧪 Testing Full Intra-repo Move (A vanishes, B appears)"
    local tmp_dir=$(mktemp -d)
    
    mkdir -p "$tmp_dir/repo/dir_a"
    cd "$tmp_dir/repo" && git init -q
    git config user.email "test@test.com"
    git config user.name "Tester"
    
    echo "data" > dir_a/file.txt
    git add . && git commit -m "feat: initial data" -q
    
    git_path_move "dir_a" "dir_b"
    
    [[ -d "dir_a" ]] && echo "❌ ERROR: dir_a still exists!" && return 1
    [[ ! -f "dir_b/file.txt" ]] && echo "❌ ERROR: dir_b/file.txt missing!" && return 1
    
    echo "✅ SUCCESS: Intra-repo seamless move."
    return 0
  }