#!/usr/bin/env bash

testConvergeMergeTripleSource() {
  echo "🧪 Testing Triple-Source Convergent Merge (Scale & Integrity)"
  
  push_state DEBUG "1"
  push_state PWD

  local tmp_dir=$(mktemp -d)
  local result=0

  (
    cd "$tmp_dir" || exit 1

    # 1. Setup Shared Base Repo
    mkdir base && cd base && git init -q
    git config user.email "base@test.com" && git config user.name "Base"
    echo "common" > common.txt
    git add . && git commit -m "feat: common base" -q
    cd "$tmp_dir"

    # 2. Create 3 divergent sources
    for id in A B C; do
      git clone base "repo$id" -q
      cd "repo$id"
      echo "data $id" > "file_$id.txt"
      git add . && git commit -m "feat: source $id" -q
      cd "$tmp_dir"
    done

    # 3. Destination Monorepo
    mkdir monorepo && cd monorepo && git init -q
    git config user.email "monorepo@test.com" && git config user.name "Mono"
    git commit --allow-empty -m "root" -q

    # 4. Execute Converge
    echo "🚀 Converging 3 sources..."
    git_path_converge_merge "merged_app" "$tmp_dir/repoA" "$tmp_dir/repoB" "$tmp_dir/repoC"

    # 5. Verification
    echo "🔍 Verifying triple-source integrity..."
    for id in A B C; do
      if [[ ! -f "merged_app/file_$id.txt" ]]; then
        echo "❌ ERROR: File from repo$id is missing!"
        exit 1
      fi
    done

    # Verify all 3 unique feature commits are in the history
    local log_count=$(git log --oneline -- merged_app | grep -E "feat: source (A|B|C)" | wc -l)
    if [[ $log_count -lt 3 ]]; then
      echo "❌ ERROR: History missing one or more source commits (found $log_count/3)"
      exit 1
    fi

    echo "✅ SUCCESS: Triple-source convergence verified."
    exit 0
  )
  result=$?
  rm -rf "$tmp_dir"

  pop_state PWD
  pop_state DEBUG
  return $result
}
