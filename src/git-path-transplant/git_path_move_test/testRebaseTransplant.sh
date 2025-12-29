#!/usr/bin/env bash

testRebaseTransplant() {
    echo "🧪 Testing Rebase Transplant (GIT_PATH_TRANSPLANT_USE_REBASE=1)"
    local tmp_dir=$(mktemp -d)
    
    # 1. Setup Source
    mkdir -p "$tmp_dir/source" && cd "$tmp_dir/source" && git init -q
    git config user.email "test@test.com" && git config user.name "Tester"
    echo "content" > feature.txt
    git add . && git commit -m "feat: source commit" -q
    
    # Extract metadata
    # We add detailed error logging if extraction fails
    local meta
    if ! meta=$(extract_git_path "$tmp_dir/source/feature.txt"); then
        echo "❌ ERROR: extract_git_path command failed"
        return 1
    fi

    if [[ ! -f "$meta" ]]; then
        echo "❌ ERROR: Metadata file not created at: $meta"
        return 1
    fi

    # 2. Setup Dest
    mkdir -p "$tmp_dir/dest" && cd "$tmp_dir/dest" && git init -q
    git config user.email "test@test.com" && git config user.name "Tester"
    echo "base" > base.txt
    git add . && git commit -m "feat: base commit" -q
    
    # 3. Execute with Rebase
    export GIT_PATH_TRANSPLANT_USE_REBASE=1
    if ! git_path_transplant "$meta" "rebased_path"; then
        echo "❌ ERROR: git_path_transplant failed"
        unset GIT_PATH_TRANSPLANT_USE_REBASE
        return 1
    fi
    unset GIT_PATH_TRANSPLANT_USE_REBASE

    # 4. Verify: Rebase results in linear history (no merge commit)
    # Total commits should be 2 (base + source), and Parent of HEAD should be the base commit
    local commit_count=$(git rev-list --count HEAD)
    local merge_count=$(git rev-list --merges HEAD | wc -l)

    if [[ $commit_count -ne 2 ]]; then
        echo "❌ ERROR: Expected 2 commits, found $commit_count"
        return 1
    fi

    if [[ $merge_count -ne 0 ]]; then
        echo "❌ ERROR: Found merge commits! Rebase failed."
        return 1
    fi

    echo "✅ SUCCESS: History transplanted via rebase (linear)."
    return 0
}
