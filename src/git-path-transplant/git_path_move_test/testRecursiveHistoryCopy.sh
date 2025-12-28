#!/usr/bin/env bash

testRecursiveHistoryCopy() {
  echo "🧪 Testing Recursive History Copy (cp -r)"
  local tmp_dir=$(mktemp -d)
  cd "$tmp_dir" && git init -q
  git config user.email "test@test.com"
  git config user.name "Tester"
  
  # Create a directory with history
  mkdir -p "project_v1"
  echo "init" > project_v1/main.c
  git add . && git commit -m "feat: initial project" -q
  echo "update" >> project_v1/main.c
  git add . && git commit -m "feat: added logic" -q

  # Run the shaded recursive copy
  git_cp_shaded -r "project_v1" "project_v2"

  # 1. Verify filesystem
  [[ ! -f "project_v2/main.c" ]] && echo "❌ ERROR: project_v2 not created." && return 1
  [[ ! -f "project_v1/main.c" ]] && echo "❌ ERROR: Source project_v1 deleted." && return 1

  # 2. Verify history presence at destination
  local history_count
  history_count=$(git log --oneline -- "project_v2" | wc -l)
  if [[ $history_count -lt 2 ]]; then
    echo "❌ ERROR: History did not follow the recursive copy. Found $history_count commits."
    return 1
  fi

  echo "✅ SUCCESS: 'cp -r' successfully forked the directory history."
  return 0
}
