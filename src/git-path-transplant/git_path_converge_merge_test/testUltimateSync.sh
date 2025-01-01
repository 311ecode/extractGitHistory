#!/usr/bin/env bash

testUltimateSync() {
  echo "🧪 Testing Ultimate Sync (Monorepo + 3 Repos Diversion)"
  
  push_state DEBUG "1"
  push_state PWD

  local tmp_dir=$(mktemp -d)
  local script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

  (
    cd "$tmp_dir" || exit 1

    # 1. SETUP: 3 Source Repos
    for id in A B C; do
      mkdir "repo$id" && cd "repo$id" && git init -q
      git config user.email "$id@test.com" && git config user.name "$id"
      echo "Data from $id" > "file_$id.txt"
      git add . && git commit -m "feat: unique content in $id" -q
      cd "$tmp_dir"
    done

    # 2. SETUP: Monorepo with local file
    mkdir monorepo && cd monorepo && git init -q
    git config user.email "m@test.com" && git config user.name "M"
    mkdir my_app
    echo "Data from Monorepo" > my_app/file_mono.txt
    git add . && git commit -m "feat: monorepo local content" -q

    # 3. EXECUTE SYNC
    source "$script_dir/git_path_converge_merge.sh"
    source "$script_dir/git_path_sync_all.sh"
    
    git_path_sync_all "my_app" "$tmp_dir/repoA" "$tmp_dir/repoB" "$tmp_dir/repoC"

    # 4. VERIFY CONTENT SYNC
    echo "🔍 Verifying total convergence..."
    
    local files=("file_mono.txt" "file_A.txt" "file_B.txt" "file_C.txt")
    
    # Check Monorepo
    for f in "${files[@]}"; do
      [[ -f "my_app/$f" ]] || { echo "❌ Monorepo missing $f"; exit 1; }
    done

    # Check Sub-repos
    for id in A B C; do
      for f in "${files[@]}"; do
        [[ -f "$tmp_dir/repo$id/$f" ]] || { echo "❌ Repo $id missing $f"; exit 1; }
      done
    done

    echo "✅ SUCCESS: Perfect Sync achieved across all 4 locations."
    exit 0
  )
  local result=$?
  rm -rf "$tmp_dir"
  pop_state PWD
  pop_state DEBUG
  return $result
}
