#!/usr/bin/env bash

testShadingBypass() {
  echo "🧪 Testing Shading Bypass Logic"
  local tmp_dir=$(mktemp -d)
  cd "$tmp_dir" && git init -q
  touch file.txt && git add file.txt && git commit -m "init" -q

  # Test 1: Simple move (Should trigger git_path_move logic)
  # We check if the 'history/' branch exists, which is a side effect of git_path_move
  git_mv_shaded file.txt moved_with_history.txt
  if git branch | grep -q "history/moved_with_history.txt"; then
    echo "✅ Success: Simple move used history preservation."
  else
    echo "❌ Error: Simple move skipped history preservation."
    return 1
  fi

  # Test 2: Move with flags (Should bypass to standard git mv)
  touch file2.txt && git add file2.txt && git commit -m "init2" -q
  git_mv_shaded -v file2.txt moved_with_flags.txt
  if git branch | grep -q "history/moved_with_flags.txt"; then
    echo "❌ Error: Flagged move incorrectly triggered history preservation."
    return 1
  else
    echo "✅ Success: Flagged move bypassed history preservation."
  fi

  return 0
}
