#!/usr/bin/env bash

testRelativeUpwardCopy() {
  echo "🧪 Testing Path Permutations (Rel/Abs) for COPY (cp)"
  
  # FORCE ENVIRONMENT
  push_state GIT_PATH_TRANSPLANT_USE_REBASE "1"
  
  # 🔒 AGGRESSIVE TEST: We deliberately set CLEANSE to 1.
  # The git_path_move script MUST override this to 0 internally because 
  # we are performing a COPY (act_like_cp=1). 
  # If the source is deleted, this safety check failed.
  push_state GIT_PATH_TRANSPLANT_USE_CLEANSE "1"
  
  push_state DEBUG "1"
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
      # 1. Setup Fresh Repo
      mkdir -p "$tmp_dir/$scenario/repo/a/b"
      mkdir -p "$tmp_dir/$scenario/repo/d/e"
      cd "$tmp_dir/$scenario/repo" && git init -q
      git config user.email "test@test.com" && git config user.name "Tester"

      # Existing file (Collateral check)
      echo "content c" > a/b/c.txt
      git add . && git commit -m "feat: initial a/b/c" -q

      # Source file with history
      echo "content f" > d/e/f.txt
      git add . && git commit -m "feat: initial d/e/f" -q
      echo "update f" >> d/e/f.txt
      git add . && git commit -m "feat: update d/e/f" -q

      # 2. Determine Paths
      local repo_root="$PWD"
      
      # Navigate to 'd' to force relative context
      cd d || exit 1

      local src_arg=""
      local dest_arg=""

      # Parse Source
      if [[ "$scenario" == "rel:"* ]]; then
        src_arg="e"
      else
        src_arg="$repo_root/d/e"
      fi

      # Parse Dest (Targeting 'a/' means we expect 'a/e' to be created)
      if [[ "$scenario" == *":rel" ]]; then
        dest_arg="../a/"
      else
        dest_arg="$repo_root/a/"
      fi

      echo "   📂 CWD:  $(pwd)"
      echo "   🎯 Cmd:  git_cp_shaded '$src_arg' '$dest_arg'"

      # 3. EXECUTE COPY
      if ! git_cp_shaded "$src_arg" "$dest_arg"; then
        echo "❌ ERROR: Command failed for scenario $scenario"
        exit 1
      fi

      # 4. VERIFICATION
      cd "$repo_root" || exit 1

      # A. Destination Verification
      if [[ ! -f "a/e/f.txt" ]]; then
        echo "❌ ERROR: Destination file 'a/e/f.txt' missing."
        ls -R
        exit 1
      fi

      # B. Source Preservation (Crucial for CP - validates Cleanse Override)
      if [[ ! -d "d/e" ]]; then
        echo "❌ ERROR: Source 'd/e' was deleted! Safety override for Cleanse failed."
        exit 1
      fi
      if [[ ! -f "d/e/f.txt" ]]; then
        echo "❌ ERROR: Source file 'd/e/f.txt' is missing."
        exit 1
      fi

      # C. Collateral Damage Check
      if [[ ! -f "a/b/c.txt" ]]; then
        echo "❌ ERROR: Existing file 'a/b/c.txt' was deleted."
        exit 1
      fi

      # D. History Verification (Destination)
      local dest_count=$(git log --oneline -- a/e/f.txt | wc -l)
      if [[ $dest_count -lt 2 ]]; then
        echo "❌ ERROR: Destination history missing. Found $dest_count commits."
        exit 1
      fi

      # E. History Verification (Source)
      local src_count=$(git log --oneline -- d/e/f.txt | wc -l)
      if [[ $src_count -lt 2 ]]; then
        echo "❌ ERROR: Source history lost. Found $src_count commits."
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
