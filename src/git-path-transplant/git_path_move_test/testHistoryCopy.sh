#!/usr/bin/env bash

testHistoryCopy() {
  echo "🧪 Testing Complex History Copy (ACT_LIKE_CP=1)"
  local tmp_dir=$(mktemp -d)
  
  # 1. Setup Source Repo with an evolving history
  mkdir -p "$tmp_dir/repo/feature_dir"
  cd "$tmp_dir/repo" && git init -q
  git config user.email "test@test.com"
  git config user.name "Tester"

  # Commit 1: Initial creation
  echo "version 1" > feature_dir/app.log
  git add . && git commit -m "feat: initial log" -q
  
  # Commit 2: Modification
  echo "version 2" >> feature_dir/app.log
  git add . && git commit -m "feat: update log to v2" -q
  
  # Commit 3: Adding a second file
  echo "config data" > feature_dir/config.json
  git add . && git commit -m "feat: add config file" -q

  local original_commit_count=$(git rev-list --count HEAD)

  # 2. Execute the history-aware copy
  # We use the shaded function which sets ACT_LIKE_CP=1 internally
  git_cp_shaded "feature_dir" "legacy_backup"

  # 3. VERIFICATION
  echo "🔍 Verifying path integrity..."
  [[ ! -d "feature_dir" ]] && echo "❌ ERROR: Source deleted!" && return 1
  [[ ! -d "legacy_backup" ]] && echo "❌ ERROR: Destination missing!" && return 1

  echo "🔍 Verifying history depth at destination..."
  # Check if the specific commit messages exist for the NEW path
  local dest_log_count
  dest_log_count=$(git log --format=%s -- "legacy_backup" | wc -l)
  
  if [[ $dest_log_count -lt 3 ]]; then
    echo "❌ ERROR: History truncated! Expected at least 3 commits, found $dest_log_count"
    return 1
  fi

  # Verify specific content evolution in the copied history
  if ! git log -p -- "legacy_backup/app.log" | grep -q "+version 2"; then
    echo "❌ ERROR: Content evolution (diff history) lost in copy!"
    return 1
  fi

  echo "🔍 Verifying source history remains untouched..."
  local source_log_count
  source_log_count=$(git log --format=%s -- "feature_dir" | wc -l)
  if [[ $source_log_count -ne 3 ]]; then
    echo "❌ ERROR: Source history corrupted during copy!"
    return 1
  fi

  echo "✅ SUCCESS: Complex history (3 commits) successfully branched to new path."
  return 0
}
