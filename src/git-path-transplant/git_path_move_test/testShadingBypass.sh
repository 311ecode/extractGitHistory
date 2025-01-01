#!/usr/bin/env bash
testShadingBypass() {
  echo "🧪 Testing Shading Bypass Logic (State Protected)"

  # ─── Minimal fix: Force mv shading for this test ───
  local restore_alias=""
  if ! alias mv 2>/dev/null | grep -q "git_mv_shaded"; then
    # Remember original state if any
    restore_alias=$(alias mv 2>/dev/null || echo "")
    register_git_mv_shade >/dev/null 2>&1
  fi

  push_state DEBUG "1"
  push_state PWD

  local tmp_dir=$(mktemp -d)
  local result=0

  (
    cd "$tmp_dir" && git init -q
    git config user.email "bypass@test.com" && git config user.name "BypassBot"
   
    touch file.txt && git add file.txt && git commit -m "init" -q
    # --- Test 1: Simple move (Should trigger history preservation) ---
    git_mv_shaded file.txt moved_with_history.txt
   
    if git branch | grep -q "history/"; then
      echo "✅ SUCCESS: Simple move used history preservation."
    else
      echo "❌ ERROR: Simple move skipped history preservation logic."
      exit 1
    fi
    # --- Test 2: Move with flags (Should bypass to standard git mv) ---
    touch file2.txt && git add file2.txt && git commit -m "init2" -q
   
    # Passing -v should trigger the bypass logic in git_mv_shaded
    git_mv_shaded -v file2.txt moved_with_flags.txt
   
    if git branch | grep -q "history/moved_with_flags.txt"; then
      echo "❌ ERROR: Flagged move (-v) incorrectly triggered history preservation."
      exit 1
    else
      echo "✅ SUCCESS: Flagged move bypassed history preservation."
    fi
   
    exit 0
  )
  result=$?

  # ─── Cleanup: Restore original alias state if we changed it ───
  if [[ -n "$restore_alias" ]]; then
    eval "$restore_alias" 2>/dev/null || true
  else
    # If we registered it and there was no previous alias, clean up
    [[ -z "$restore_alias" ]] && deregister_git_mv_shade >/dev/null 2>&1
  fi

  pop_state PWD
  pop_state DEBUG
  return $result
}
