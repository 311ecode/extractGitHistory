#!/usr/bin/env bash
testHashParityRoundTrip() {
    echo "🧪 Testing History & Content Parity (Deterministic Round-Trip Check)"
    local tmp_dir=$(mktemp -d)
    local debug="${DEBUG:-}"

    # ── Source repo ───────────────────────────────────────────────────────
    mkdir -p "$tmp_dir/orig" && cd "$tmp_dir/orig" && git init -q
    git config user.email "parity@test.com" && git config user.name "ParityBot"
    echo "content" > file.txt
    GIT_AUTHOR_DATE="2025-01-01T12:00:00Z" GIT_COMMITTER_DATE="2025-01-01T12:00:00Z" \
      git add file.txt && git commit -m "fix: logic" -q

    local orig_content=$(cat file.txt)
    local orig_commit_info=$(git show --format='%s%n%an <%ae>%n%ai' HEAD)
    local orig_tree=$(git rev-parse HEAD^{tree})

    # Initial extract
    local meta
    meta=$(extract_git_path "$tmp_dir/orig/file.txt")
    [[ ! -f "$meta" ]] && { echo "❌ Initial extraction failed"; return 1; }

    # ── Monorepo + transplant ─────────────────────────────────────────────
    local monorepo_root="$tmp_dir/monorepo"
    mkdir -p "$monorepo_root" && cd "$monorepo_root" && git init -q
    git config user.email "parity@test.com" && git config user.name "ParityBot"
    git commit --allow-empty -m "root" -q

    git_path_transplant "$meta" "moved/here"

    git checkout "history/moved/here" --quiet 2>/dev/null || {
        echo "❌ Failed to checkout history branch"; return 1
    }

    # Re-extract
    local second_meta
    second_meta=$(extract_git_path "$monorepo_root/moved/here/file.txt")
    [[ ! -f "$second_meta" ]] && { echo "❌ Re-extraction failed"; return 1; }

    local final_repo
    final_repo=$(jq -r '.extracted_repo_path // empty' "$second_meta")
    [[ -z "$final_repo" || ! -d "$final_repo" ]] && {
        echo "❌ Invalid extracted repo"; return 1
    }

    cd "$final_repo" || return 1

    # Read content — file should be flattened to root by extract_git_path
    local final_content
    final_content=$(cat file.txt 2>/dev/null) || {
        echo "❌ Cannot read file.txt in extracted repo (expected at root)" >&2
        ls -R >&2
        return 1
    }

    local final_commit_info=$(git show --format='%s%n%an <%ae>%n%ai' HEAD)
    local final_tree=$(git rev-parse HEAD^{tree})

    echo "📊 Parity Comparison:"
    echo "Original commit info: $orig_commit_info"
    echo "Final    commit info: $final_commit_info"
    echo "Original tree hash:   $orig_tree"
    echo "Final    tree hash:   $final_tree"
    echo "Content:              $orig_content → $final_content"

    if [[ "$orig_content" == "$final_content" &&
          "$orig_commit_info" == "$final_commit_info" &&
          "$orig_tree" == "$final_tree" ]]; then
        echo "✅ SUCCESS: Full content, metadata and tree parity preserved!"
        return 0
    else
        echo "❌ ERROR: Parity check failed!"
        if [[ -n "$debug" ]]; then
            echo "--- Original ---" >&2
            git -C "$tmp_dir/orig" show HEAD >&2
            echo "--- Final ---" >&2
            git show HEAD >&2
            echo "Directory structure in final repo:" >&2
            ls -R >&2
        fi
        return 1
    fi
}
