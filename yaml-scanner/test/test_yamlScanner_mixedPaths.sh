#!/usr/bin/env bash
test_yamlScanner_mixedPaths() {
  echo "Testing mixed absolute and relative paths"

  local test_dir
  test_dir=$(mktemp -d)

  # Create the actual directories so existence checks pass
  local absolute_target="$test_dir/abs-repo"
  local relative_target="$test_dir/rel-repo"
  mkdir -p "$absolute_target"
  mkdir -p "$relative_target"

  local yaml_file="$test_dir/.github-sync.yaml"

  # We use the full path to $test_dir/abs-repo to simulate an absolute path
  cat >"$yaml_file" <<EOF
github_user: testuser

projects:
  - path: $absolute_target
    repo_name: absolute-path
  - path: ./rel-repo
    repo_name: relative-path
EOF

  # Execute scanner
  local output
  output=$(yaml_scanner "$yaml_file" 2>/dev/null)
  local exit_code=$?

  if [[ $exit_code -ne 0 ]]; then
    echo "ERROR: yaml_scanner failed"
    rm -rf "$test_dir"
    return 1
  fi

  # Verify absolute path remained correct
  local path1
  path1=$(echo "$output" | jq -r '.[0].path' 2>/dev/null)
  if [[ $path1 != "$absolute_target" ]]; then
    echo "ERROR: Absolute path was modified or incorrect"
    echo "Expected: $absolute_target"
    echo "Got: $path1"
    rm -rf "$test_dir"
    return 1
  fi

  # Verify relative path was correctly resolved
  local path2
  path2=$(echo "$output" | jq -r '.[1].path' 2>/dev/null)
  if [[ $path2 != "$relative_target" ]]; then
    echo "ERROR: Relative path not resolved correctly"
    echo "Expected: $relative_target"
    echo "Got: $path2"
    rm -rf "$test_dir"
    return 1
  fi

  echo "SUCCESS: Mixed paths work correctly"
  rm -rf "$test_dir"
  return 0
}
