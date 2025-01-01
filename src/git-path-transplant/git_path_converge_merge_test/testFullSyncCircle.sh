#!/usr/bin/env bash

testFullSyncCircle() {
  echo "🧪 Testing Triple-Source Magic Circle (Converge -> Modify -> Distribute)"
  
  push_state DEBUG "1"
  push_state PWD

  local tmp_dir=$(mktemp -d)
  local script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

  (
    cd "$tmp_dir" || exit 1

    # 1. Setup Source Repos
    for id in A B C; do
      mkdir "repo$id" && cd "repo$id" && git init -q
      git config user.email "$id@test.com" && git config user.name "$id"
      echo "Original $id" > "file$id.txt"
      git add . && git commit -m "init $id" -q
      cd "$tmp_dir"
    done

    # 2. Converge into Monorepo
    mkdir monorepo && cd monorepo && git init -q
    git config user.email "mono@test.com" && git config user.name "Mono"
    git commit --allow-empty -m "root" -q
    
    source "$script_dir/git_path_converge_merge.sh"
    export GIT_PATH_TRANSPLANT_USE_CLEANSE=0
    git_path_converge_merge "unified_app" "$tmp_dir/repoA" "$tmp_dir/repoB" "$tmp_dir/repoC"

    # 3. Modify in Monorepo
    echo "GLOBAL MAGIC SYNC" >> unified_app/global.txt
    git add . && git commit -m "feat: global sync change" -q

    # 4. Distribute (Circle Back)
    source "$script_dir/git_path_distribute_sync.sh"
    git_path_distribute_sync "unified_app" "$tmp_dir/repoA" "$tmp_dir/repoB" "$tmp_dir/repoC"

    # 5. Verify all 3 repos are synced
    for id in A B C; do
      if grep -q "GLOBAL MAGIC SYNC" "$tmp_dir/repo$id/global.txt" 2>/dev/null; then
        echo "✅ Repo $id synced successfully."
      else
        echo "❌ ERROR: Repo $id missing sync content."
        exit 1
      fi
    done
    exit 0
  )
  local result=$?
  rm -rf "$tmp_dir"
  pop_state PWD
  pop_state DEBUG
  return $result
}
