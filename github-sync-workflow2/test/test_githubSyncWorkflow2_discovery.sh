#!/usr/bin/env bash
# Date: 2026-03-04

test_githubSyncWorkflow2_discovery() {
  echo "Testing project discovery via sidecar markers..."

  local test_root=$(mktemp -d)
  local json_out="$test_root/output.json"
  
  # Setup Project A: Simple default sync
  mkdir -p "$test_root/util/projectA"
  mkdir -p "$test_root/util/projectA-github-sync.d"
  touch "$test_root/util/projectA-github-sync.d/sync"

  # Setup Project B: With overrides in the sync file
  mkdir -p "$test_root/vcs/projectB"
  mkdir -p "$test_root/vcs/projectB-github-sync.d"
  cat > "$test_root/vcs/projectB-github-sync.d/sync" <<EOF
repo_name="custom-repo-name"
private=false
githubPages=true
EOF

  # Setup Noise: Folder without a sidecar (should be ignored)
  mkdir -p "$test_root/ignore-me"

  # Run discovery
  github_sync_discover_projects2 "$test_root" "$json_out" "false"

  # Assertions
  local count=$(jq 'length' "$json_out")
  if [[ $count -ne 2 ]]; then
    echo "ERROR: Expected 2 projects, found $count" >&2
    rm -rf "$test_root"
    return 1
  fi

  # Check Project A defaults
  if ! jq -e '.[] | select(.repo_name == "projectA" and .private == "true")' "$json_out" >/dev/null; then
    echo "ERROR: Project A discovery failed or defaults incorrect" >&2
    return 1
  fi

  # Check Project B overrides
  if ! jq -e '.[] | select(.repo_name == "custom-repo-name" and .githubPages == "true")' "$json_out" >/dev/null; then
    echo "ERROR: Project B override parsing failed" >&2
    return 1
  fi

  echo "SUCCESS: Discovery correctly identified sidecars and parsed configs."
  rm -rf "$test_root"
  return 0
}

test_githubSyncWorkflow2_packagesh_hook() {
  echo "Testing packagesh hook execution and variable injection..."

  local test_root=$(mktemp -d)
  local json_out="$test_root/output.json"
  local hook_out="$test_root/hook_output.txt"

  # Setup Mock Monorepo with a Sidecar and Publish Script
  mkdir -p "$test_root/src/my-internal-tool"
  mkdir -p "$test_root/src/my-internal-tool-github-sync.d"
  
  # Create sync file with repo_name override
  cat > "$test_root/src/my-internal-tool-github-sync.d/sync" <<EOF
repo_name="public-awesome-tool"
EOF

  # Create mock publish script matching the hook expectations
  cat > "$test_root/src/my-internal-tool-github-sync.d/publish_my_internal_tool.sh" <<EOF
publish_my_internal_tool() {
    echo "HOOK_TRIGGERED_WITH: \$PACKAGESH_REPO_NAME_OVERRIDE" > "$hook_out"
}
EOF
  chmod +x "$test_root/src/my-internal-tool-github-sync.d/publish_my_internal_tool.sh"

  # Run discovery
  github_sync_discover_projects2 "$test_root" "$json_out" "false"

  # Assertions
  if [[ ! -f "$hook_out" ]]; then
    echo "ERROR: Hook script was not executed by discovery engine." >&2
    rm -rf "$test_root"
    return 1
  fi

  local hook_result
  hook_result=$(cat "$hook_out")
  
  if [[ "$hook_result" != "HOOK_TRIGGERED_WITH: public-awesome-tool" ]]; then
    echo "ERROR: Variable injection failed or mismatched. Output: $hook_result" >&2
    rm -rf "$test_root"
    return 1
  fi

  echo "SUCCESS: Hook triggered and PACKAGESH_REPO_NAME_OVERRIDE injected correctly."
  rm -rf "$test_root"
  return 0
}
