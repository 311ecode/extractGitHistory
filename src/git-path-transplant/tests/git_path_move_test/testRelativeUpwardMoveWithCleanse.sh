#!/usr/bin/env bash

testRelativeUpwardMoveWithCleanse() {
  echo "🧪 Testing Path Permutations (Rel/Abs) with Rebase & Cleanse"
  
  # FORCE ENVIRONMENT
  push_state GIT_PATH_TRANSPLANT_USE_REBASE "1"
  push_state GIT_PATH_TRANSPLANT_USE_CLEANSE "1"
  push_state DEBUG "1" # Keep debug on to see the permutations
  push_state PWD

  local tmp_dir=$(mktemp -d)
  local result=0

  # Define scenarios: "SOURCE_TYPE:DEST_TYPE"
  local scenarios=(
    "rel:rel"
    "rel:abs"
    "abs:rel"
    "abs:abs"
  )

  for scenario in "${scenarios[@]}"; do
    echo "---------------------------------------------------"
    echo "🔄 Running Scenario: $scenario"
    echo "---------------------------------------------------"

    (
      # 1. Setup Fresh Repo for each iteration
      mkdir -p "$tmp_dir/$scenario/repo/a/b"
      mkdir -p "$tmp_dir/$scenario/repo/d/e"
      cd "$tmp_dir/$scenario/repo" && git init -q
      git config user.email "test@test.com" && git config user.name "Tester"

      # Create colliding target to test merge resilience
      echo "content c" > a/b/c.txt
      git add . && git commit -m "feat: initial a/b/c" -q

      # Create source with history
      echo "content f" > d/e/f.txt
      git add . && git commit -m "feat: initial d/e/f" -q
      echo "update f" >> d/e/f.txt
      git add . && git commit -m "feat: update d/e/f" -q

      # 2. Determine Paths
      local repo_root="$PWD"
      
      # We intentionally CD into 'd' to force relative context
      cd d || exit 1

      local src_arg=""
      local dest_arg=""

      # Parse Source Type
      if [[ "$scenario" == "rel:"* ]]; then
        src_arg="e"
      else
        src_arg="$repo_root/d/e"
      fi

      # Parse Dest Type
      if [[ "$scenario" == *":rel" ]]; then
        dest_arg="../a/"
      else
        dest_arg="$repo_root/a/"
      fi

      echo "   📂 CWD:  $(pwd)"
      echo "   🎯 Cmd:  git_mv_shaded '$src_arg' '$dest_arg'"

      # 3. EXECUTE
      if ! git_mv_shaded "$src_arg" "$dest_arg"; then
        echo "❌ ERROR: Command failed for scenario $scenario"
        exit 1
      fi

      # 4. VERIFICATION
      cd "$repo_root" || exit 1

      # A. File Placement
      if [[ ! -f "a/e/f.txt" ]]; then
        echo "❌ ERROR: File missing at destination 'a/e/f.txt'"
        ls -R
        exit 1
      fi

      # B. Source Removal
      if [[ -d "d/e" ]]; then
        echo "❌ ERROR: Source 'd/e' not removed."
        exit 1
      fi

      # C. Collateral Damage Check
      if [[ ! -f "a/b/c.txt" ]]; then
        echo "❌ ERROR: Existing file 'a/b/c.txt' was deleted!"
        exit 1
      fi

      # D. History Verification
      local hist_count=$(git log --oneline -- a/e/f.txt | wc -l)
      if [[ $hist_count -lt 2 ]]; then
        echo "❌ ERROR: History missing. Found $hist_count commits (Expected 2+)."
        exit 1
      fi

      # E. Cleanse Verification
      if git log --all -- "d/e/f.txt" | grep -q "feat:"; then
        echo "❌ ERROR: Cleanse failed. Old path history remains."
        exit 1
      fi

      echo "✅ Scenario $scenario PASSED"
    ) || { result=1; break; }
  done

  rm -rf "$tmp_dir"
  pop_state PWD
  pop_state DEBUG
  pop_state GIT_PATH_TRANSPLANT_USE_CLEANSE
  pop_state GIT_PATH_TRANSPLANT_USE_REBASE

  return $result
}
