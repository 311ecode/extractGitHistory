#!/usr/bin/env bash

testConvergeMergeFullSync() {
  echo "🧪 Testing Full Content Sync (Magic Convergence)"
  
  push_state DEBUG "1"
  push_state PWD

  local tmp_dir=$(mktemp -d)
  local result=0

  (
    cd "$tmp_dir" || exit 1

    # 1. Create 3 repos with unique content and different committers
    declare -A expected_content
    for id in A B C; do
      mkdir "repo$id" && cd "repo$id" && git init -q
      git config user.email "$id@test.com" && git config user.name "Author $id"
      
      local filename="file_$id.txt"
      local content="Unique magic content for $id"
      expected_content[$filename]="$content"
      
      echo "$content" > "$filename"
      git add . && git commit -m "feat: unique commit from $id" -q
      cd "$tmp_dir"
    done

    # 2. Setup Destination
    mkdir monorepo && cd monorepo && git init -q
    git config user.email "sync@test.com" && git config user.name "SyncBot"
    git commit --allow-empty -m "initial empty" -q

    # 3. Source the converge script (to avoid 'command not found')
    source ../../git_path_converge_merge.sh
    # Also source the 'project_converge' if you want to use the wrapper
    # source ../../git_path_project_converge.sh

    # 4. EXECUTE MAGIC
    echo "🚀 Converging all repos into 'unified_project'..."
    # We set this to 0 to prevent the BFG deletion bug you saw earlier
    export GIT_PATH_TRANSPLANT_USE_CLEANSE=0
    git_path_converge_merge "unified_project" "$tmp_dir/repoA" "$tmp_dir/repoB" "$tmp_dir/repoC"

    # 5. CONTENT SYNC VERIFICATION
    echo "🔍 Verifying file-level content sync..."
    for file in "${!expected_content[@]}"; do
      local actual_file="unified_project/$file"
      if [[ ! -f "$actual_file" ]]; then
        echo "❌ ERROR: $file is missing from destination!"
        exit 1
      fi
      
      local content=$(cat "$actual_file")
      if [[ "$content" != "${expected_content[$file]}" ]]; then
        echo "❌ ERROR: Content mismatch in $file!"
        echo "   Expected: ${expected_content[$file]}"
        echo "   Got:      $content"
        exit 1
      fi
      echo "✅ $file synced correctly."
    done

    # 6. HISTORY SYNC VERIFICATION
    echo "🔍 Verifying history union..."
    local commit_count=$(git log --oneline -- unified_project | grep "feat: unique commit from" | wc -l)
    if [[ $commit_count -ne 3 ]]; then
      echo "❌ ERROR: History union failed. Expected 3 feature commits, found $commit_count."
      exit 1
    fi
    echo "✅ All 3 source histories merged."

    exit 0
  )
  result=$?
  rm -rf "$tmp_dir"

  pop_state PWD
  pop_state DEBUG
  return $result
}
