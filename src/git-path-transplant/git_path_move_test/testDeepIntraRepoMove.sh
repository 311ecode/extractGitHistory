#!/usr/bin/env bash
testDeepIntraRepoMove() {
    echo "🧪 Testing Deep Move (Creating nested parents)"
    local tmp_dir=$(mktemp -d)
    
    mkdir -p "$tmp_dir/repo/src"
    cd "$tmp_dir/repo" && git init -q
    git config user.email "test@test.com"
    git config user.name "Tester"
    echo "logic" > src/app.js
    git add . && git commit -m "feat: app" -q
    
    git_path_move "src" "internal/modules/core/app-code"
    
    [[ ! -f "internal/modules/core/app-code/app.js" ]] && echo "❌ ERROR: Nested path not created!" && return 1
    echo "✅ SUCCESS: Deep move with mkdir -p."
    return 0
  }