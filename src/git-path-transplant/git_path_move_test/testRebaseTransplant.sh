#!/usr/bin/env bash

testRebaseTransplant() {
    echo "🧪 Testing Rebase Transplant (Linear History Check)"
    
    # 1. DEFINE SANDBOX STATE
    # Force Rebase mode and deterministic dates
    push_state GIT_PATH_TRANSPLANT_USE_REBASE "1"
    push_state GIT_PATH_TRANSPLANT_USE_CLEANSE "0"
    push_state GIT_AUTHOR_DATE "2025-01-01T12:00:00Z"
    push_state GIT_COMMITTER_DATE "2025-01-01T12:00:00Z"
    export GIT_AUTHOR_DATE GIT_COMMITTER_DATE
    
    push_state DEBUG "1"
    push_state PWD

    local tmp_dir=$(mktemp -d)
    local result=0

    (
        # 1. Setup Source
        mkdir -p "$tmp_dir/source" && cd "$tmp_dir/source" && git init -q
        git config user.email "test@test.com" && git config user.name "Tester"
        echo "content" > feature.txt
        git add . && git commit -m "feat: source commit" -q
        
        # Extract metadata
        local meta
        meta=$(extract_git_path "$tmp_dir/source/feature.txt") || exit 1

        # 2. Setup Destination
        mkdir -p "$tmp_dir/dest" && cd "$tmp_dir/dest" && git init -q
        git config user.email "test@test.com" && git config user.name "Tester"
        echo "base" > base.txt
        git add . && git commit -m "feat: base commit" -q
        
        # 3. Execute with Rebase (Triggered by the pushed state)
        git_path_transplant "$meta" "rebased_path" || exit 1

        # 4. VERIFICATION: Linear history check
        # Total commits should be 2 (base + source)
        local commit_count=$(git rev-list --count HEAD)
        # Merge commits should be 0
        local merge_count=$(git rev-list --merges HEAD | wc -l)

        if [[ $commit_count -ne 2 ]]; then
            echo "❌ ERROR: Expected 2 commits (linear), found $commit_count"
            exit 1
        fi

        if [[ $merge_count -ne 0 ]]; then
            echo "❌ ERROR: Found merge commits! Rebase failed to linearize history."
            exit 1
        fi

        echo "✅ SUCCESS: History transplanted via rebase (Verified linear)."
        exit 0
    )
    result=$?

    # 5. RESTORE ORIGINAL STATE
    pop_state PWD
    pop_state DEBUG
    pop_state GIT_COMMITTER_DATE
    pop_state GIT_AUTHOR_DATE
    pop_state GIT_PATH_TRANSPLANT_USE_CLEANSE
    pop_state GIT_PATH_TRANSPLANT_USE_REBASE

    return $result
}
