#!/usr/bin/env bash

testInterRepoMoveSafety() {
    echo "🧪 Testing Inter-repo move (Source must be preserved)"
    
    push_state PWD
    push_state DEBUG "1"
    push_state GIT_PATH_TRANSPLANT_ACT_LIKE_CP "0"
    push_state GIT_PATH_TRANSPLANT_USE_CLEANSE "0"

    local tmp_dir=$(mktemp -d)
    local result=0
    
    (
        # Source repo setup
        mkdir -p "$tmp_dir/source_repo/utils"
        cd "$tmp_dir/source_repo" && git init -q
        git config user.email "test@test.com" && git config user.name "Tester"
        echo "code" > utils/tool.sh
        git add . && git commit -m "feat: utils" -q

        # Dest repo setup
        mkdir -p "$tmp_dir/dest_repo"
        cd "$tmp_dir/dest_repo" && git init -q
        git config user.email "test@test.com" && git config user.name "Tester"
        git commit --allow-empty -m "init" -q

        # Run move
        git_path_move "$tmp_dir/source_repo/utils" "imported_utils"

        # VERIFY
        if [[ ! -d "$tmp_dir/source_repo/utils" ]]; then
          echo "❌ ERROR: Source deleted in INTER-repo move! Safety violation."
          exit 1
        fi
        
        if [[ ! -d "imported_utils" ]]; then
          echo "❌ ERROR: Destination directory missing!"
          exit 1
        fi

        echo "✅ SUCCESS: Inter-repo source preserved."
        exit 0
    )
    result=$?

    pop_state GIT_PATH_TRANSPLANT_USE_CLEANSE
    pop_state GIT_PATH_TRANSPLANT_ACT_LIKE_CP
    pop_state DEBUG
    pop_state PWD

    return $result
}
