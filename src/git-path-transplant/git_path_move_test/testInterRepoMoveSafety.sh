#!/usr/bin/env bash
testInterRepoMoveSafety() {
    echo "🧪 Testing Inter-repo move (Source must be preserved)"
    local tmp_dir=$(mktemp -d)
    
    mkdir -p "$tmp_dir/source_repo/utils"
    cd "$tmp_dir/source_repo" && git init -q
    git config user.email "test@test.com"
    git config user.name "Tester"
    echo "code" > utils/tool.sh
    git add . && git commit -m "feat: utils" -q

    mkdir -p "$tmp_dir/dest_repo"
    cd "$tmp_dir/dest_repo" && git init -q
    git config user.email "test@test.com"
    git config user.name "Tester"
    git commit --allow-empty -m "init" -q

    git_path_move "$tmp_dir/source_repo/utils" "imported_utils"

    if [[ ! -d "$tmp_dir/source_repo/utils" ]]; then
      echo "❌ ERROR: Source deleted in INTER-repo move! Safety violation."
      return 1
    fi
    echo "✅ SUCCESS: Inter-repo source preserved."
    return 0
  }