#!/usr/bin/env bash

testTransplantSafety() {
  echo "🧪 Testing Transplant Safety (State Protected: Dirty Source & Collisions)"
  
  # 1. PROTECT ENVIRONMENT
  push_state DEBUG "1"
  push_state PWD

  local tmp_dir=$(mktemp -d)
  local result=0

  (
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
      exit 1
    fi
    echo "✅ SUCCESS: Dirty tree blocked transplant."
    
    # Cleanup dirty state for next scenario
    rm dirty.txt

    # --- Scenario 2: Destination Already Exists ---
    mkdir -p "existing_dir"
    if git_path_transplant "$fake_meta" "existing_dir" 2>/dev/null; then
      echo "❌ ERROR: Transplant allowed over existing directory!"
      exit 1
    fi
    echo "✅ SUCCESS: Existing destination blocked transplant."

    # --- Scenario 3: Destination is Ignored ---
    echo "ignored_path/" > .gitignore
    git add .gitignore && git commit -m "ignore config" -q
    
    if git_path_transplant "$fake_meta" "ignored_path" 2>/dev/null; then
      echo "❌ ERROR: Transplant allowed into ignored path!"
      exit 1
    fi
    echo "✅ SUCCESS: Ignored destination blocked transplant."

    exit 0
  )
  result=$?

  # 2. RESTORE ENVIRONMENT
  pop_state PWD
  pop_state DEBUG

  return $result
}
