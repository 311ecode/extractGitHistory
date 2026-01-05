#!/usr/bin/env bash
test_full_integration_dry_run() {
  echo "🧪 Testing full integration (Extraction -> Pusher Dry Run)"

  # 1. Setup local source
  local local_source="/tmp/gh-pusher-test-source"
  rm -rf "$local_source"
  mkdir -p "$local_source/subdir"

  (
    cd "$local_source" || exit 1
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "# Test Project Description" >subdir/README.md
    echo "data" >subdir/file.txt
    git add .
    git commit -qm "initial commit"
  )

  # 2. Extract and capture output
  local extraction_output
  extraction_output=$(gitHistoryTools_extractGitPath "$local_source/subdir")

  # Extract ONLY the line that is an absolute path to a .json file
  local meta_file
  meta_file=$(echo "$extraction_output" | grep -o "/.*\.json$" | tail -n 1)

  if [[ ! -f $meta_file ]]; then
    echo "❌ ERROR: Valid meta.json path not captured. Output was:"
    echo "$extraction_output"
    return 1
  fi

  # 3. Modify meta.json using a temp directory to prevent stream conflicts
  local target_name="gh-pusher-test-integration"
  local workspace
  workspace=$(dirname "$meta_file")

  # Use a subshell to perform the update
  (
    cd "$workspace" || exit 1
    jq --arg name "$target_name" '.custom_repo_name = $name' "extract-git-path-meta.json" >"meta.tmp"
    mv "meta.tmp" "extract-git-path-meta.json"
  )

  # VERIFICATION: Ensure the file on disk actually has the value
  local check_name
  check_name=$(jq -r '.custom_repo_name // "null"' "$meta_file")

  if [[ $check_name != "$target_name" ]]; then
    echo "❌ ERROR: Failed to update meta.json at $meta_file"
    echo "Content of file:"
    cat "$meta_file"
    return 1
  fi

  # 4. Run Pusher
  local output
  output=$(github_pusher "$meta_file" "true" 2>&1)

  if [[ -n ${DEBUG:-} ]]; then
    echo "--- PUSHER OUTPUT ---"
    echo "$output"
    echo "---------------------"
  fi

  # 5. Final validation
  if echo "$output" | grep -q "$target_name"; then
    echo "✅ SUCCESS: Integrated flow confirmed"
    rm -rf "$local_source"
    return 0
  else
    echo "❌ ERROR: Pusher still used default name: $(echo "$output" | grep "Generated repo name:" | head -n 1)"
    return 1
  fi
}
