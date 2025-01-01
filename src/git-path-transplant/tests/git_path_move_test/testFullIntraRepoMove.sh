#!/usr/bin/env bash

testFullIntraRepoMove() {
    echo "🧪 Testing Full Intra-repo Move (State Protected: A vanishes, B appears)"
    
    # 1. SETUP PRISTINE STATE
    # Ensure we are testing a standard MOVE (not a CP and not a CLEANSE)
    push_state GIT_PATH_TRANSPLANT_ACT_LIKE_CP "0"
    push_state GIT_PATH_TRANSPLANT_USE_CLEANSE "0"
    push_state DEBUG "1"
    push_state PWD

    local tmp_dir=$(mktemp -d)
    local result=0
    
    # 2. EXECUTE TEST IN ISOLATION
    (
        mkdir -p "$tmp_dir/repo/dir_a"
        cd "$tmp_dir/repo" && git init -q
        git config user.email "test@test.com"
        git config user.name "Tester"
        
        echo "data" > dir_a/file.txt
        git add . && git commit -m "feat: initial data" -q
        
        # Perform the move
        git_path_move "dir_a" "dir_b"
        
        # 3. VERIFICATION
        if [[ -d "dir_a" ]]; then
            echo "❌ ERROR: dir_a still exists! (Move failed to remove source)"
            exit 1
        fi
        
        if [[ ! -f "dir_b/file.txt" ]]; then
            echo "❌ ERROR: dir_b/file.txt missing! (Move failed to create destination)"
            exit 1
        fi
        
        echo "✅ SUCCESS: Intra-repo seamless move verified."
        exit 0
    )
    result=$?

    # 4. RESTORE ORIGINAL STATE
    pop_state PWD
    pop_state DEBUG
    pop_state GIT_PATH_TRANSPLANT_USE_CLEANSE
    pop_state GIT_PATH_TRANSPLANT_ACT_LIKE_CP
    
    return $result
}
