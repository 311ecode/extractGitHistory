#!/usr/bin/env bash

testTransplantSafety() {
  echo "🧪 Testing Transplant Safety (Dirty Source & Dest Collision)"
  local tmp_dir=$(mktemp -d)
  
  # Setup Repo
  mkdir -p "$tmp_dir/repo" && cd "$tmp_dir/repo" && git init -q
  git config user.email "safety@test.com"
  git config user.name "SafetyBot"
  echo "initial" > base.txt
  git add . && git commit -m "root" -q

  # Create a dummy meta file for testing
  local fake_meta="$tmp_dir/fake.json"
  echo '{"extracted_repo_path": "/tmp/null"}' > "$fake_meta"

  # --- Scenario 1: Dirty Working Directory ---
  echo "dirty change" > dirty.txt
  # We don't git add/commit, so the repo is dirty
  
  if git_path_transplant "$fake_meta" "new_path" 2>/dev/null; then
    echo "❌ ERROR: Transplant allowed on dirty working tree!"
    return 1
  fi
  echo "✅ SUCCESS: Dirty tree blocked transplant."
  
  # Cleanup dirty state
  rm dirty.txt

  # --- Scenario 2: Destination Already Exists ---
  mkdir -p "existing_dir"
  if git_path_transplant "$fake_meta" "existing_dir" 2>/dev/null; then
    echo "❌ ERROR: Transplant allowed over existing directory!"
    return 1
  fi
  echo "✅ SUCCESS: Existing destination blocked transplant."

  # --- Scenario 3: Destination is Ignored ---
  echo "ignored_path/" > .gitignore
  git add .gitignore && git commit -m "ignore config" -q
  
  if git_path_transplant "$fake_meta" "ignored_path" 2>/dev/null; then
    echo "❌ ERROR: Transplant allowed into ignored path!"
    return 1
  fi
  echo "✅ SUCCESS: Ignored destination blocked transplant."

  return 0
}
