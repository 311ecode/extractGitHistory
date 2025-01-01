#!/usr/bin/env bash

testHashParityRoundTrip() {
    echo "🧪 Testing Hash Parity Round-Trip (Deterministic Sandbox)"
    
    push_state GIT_AUTHOR_DATE "2025-01-01T12:00:00Z"
    push_state GIT_COMMITTER_DATE "2025-01-01T12:00:00Z"
    export GIT_AUTHOR_DATE GIT_COMMITTER_DATE

    push_state GIT_PATH_TRANSPLANT_USE_REBASE "1"
    push_state GIT_PATH_TRANSPLANT_USE_CLEANSE "0"
    push_state DEBUG "1"
    push_state PWD

    local tmp_dir=$(mktemp -d)
    local result=0

    (
        # 1. Setup Original
        mkdir -p "$tmp_dir/orig" && cd "$tmp_dir/orig" && git init -q
        git config user.email "parity@test.com" && git config user.name "ParityBot"
        echo "content" > file.txt
        git add file.txt && git commit -m "fix: logic" -q
        local orig_commit_info=$(git show --format='%s%n%an <%ae>%n%ai' HEAD)
        local orig_tree=$(git rev-parse HEAD^{tree})

        # 2. Setup Monorepo
        local monorepo_root="$tmp_dir/monorepo"
        mkdir -p "$monorepo_root" && cd "$monorepo_root" && git init -q
        git config user.email "parity@test.com" && git config user.name "ParityBot"
        git commit --allow-empty -m "root" -q

        # 3. Transplant & Re-extract
        local meta=$(extract_git_path "$tmp_dir/orig/file.txt") || exit 1
        
        # FIX: Explicitly target the full file path.
        # Previously "moved/here" treated 'here' as the filename.
        git_path_transplant "$meta" "moved/here/file.txt" || exit 1

        local second_meta=$(extract_git_path "$monorepo_root/moved/here/file.txt") || exit 1
        local final_repo=$(jq -r '.extracted_repo_path' "$second_meta")
        cd "$final_repo" || exit 1

        # FIX: Find the commit that specifically matches our content, not just HEAD
        local target_commit=$(git log --all --grep="fix: logic" --format=%H -n 1)
        local final_commit_info=$(git show --format='%s%n%an <%ae>%n%ai' "$target_commit")
        local final_tree=$(git rev-parse "$target_commit^{tree}")

        if [[ "$orig_commit_info" == "$final_commit_info" && "$orig_tree" == "$final_tree" ]]; then
            echo "✅ SUCCESS: Hash and Metadata parity preserved!"
            exit 0
        else
            echo "❌ ERROR: Parity check failed!"
            echo "Original: $orig_commit_info"
            echo "Final:    $final_commit_info"
            exit 1
        fi
    )
    result=$?

    pop_state PWD DEBUG GIT_PATH_TRANSPLANT_USE_CLEANSE GIT_PATH_TRANSPLANT_USE_REBASE GIT_COMMITTER_DATE GIT_AUTHOR_DATE
    return $result
}
