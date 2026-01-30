#!/usr/bin/env bash
# Date: 2026-01-30

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
