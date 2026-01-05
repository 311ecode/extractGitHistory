#!/usr/bin/env bash
test_yamlScanner_relativePaths() {
  echo "Testing relative path resolution"

  local test_dir
  test_dir=$(mktemp -d)

  # Create the targets
  mkdir -p "$test_dir/projects/subdir1"
  mkdir -p "$test_dir/projects/subdir2"

  local yaml_file="$test_dir/.github-sync.yaml"

  cat >"$yaml_file" <<EOF
github_user: testuser
projects:
  - path: ./projects/subdir1
    repo_name: relative-with-dot
  - path: projects/subdir2
    repo_name: relative-without-dot
EOF

  # Execute (Ensure we capture only stdout for jq)
  local output
  output=$(yaml_scanner "$yaml_file" 2>/dev/null)
  local exit_code=$?

  if [[ $exit_code -ne 0 ]]; then
    echo "ERROR: yaml_scanner failed (Exit: $exit_code)"
    rm -rf "$test_dir"
    return 1
  fi

  # Verify Path 1
  local path1
  path1=$(echo "$output" | jq -r '.[0].path' 2>/dev/null)
  if [[ $path1 != "$test_dir/projects/subdir1" ]]; then
    echo "ERROR: Path 1 resolution failed."
    echo "Got: '$path1'"
    rm -rf "$test_dir"
    return 1
  fi

  echo "SUCCESS: Relative path resolution works"
  rm -rf "$test_dir"
  return 0
}
