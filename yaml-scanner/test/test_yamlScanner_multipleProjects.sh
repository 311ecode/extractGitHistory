#!/usr/bin/env bash
test_yamlScanner_multipleProjects() {
  echo "Testing multiple projects extraction"

  local test_dir=$(mktemp -d)
  local yaml_file="$test_dir/.github-sync.yaml"

  # Create the actual directories so the scanner's existence check passes
  # We create them inside test_dir to keep the test hermetic
  mkdir -p "$test_dir/repo1"
  mkdir -p "$test_dir/repo2"
  mkdir -p "$test_dir/another-project"

  cat >"$yaml_file" <<EOF
github_user: testuser

projects:
  - path: $test_dir/repo1
    repo_name: custom-repo-1
  - path: $test_dir/repo2
  - path: $test_dir/another-project
    repo_name: special-name
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

  # Verify project count
  local count
  count=$(echo "$output" | jq '. | length')
  if [[ $count -ne 3 ]]; then
    echo "ERROR: Expected 3 projects, got $count"
    rm -rf "$test_dir"
    return 1
  fi

  # Verify first project repo_name
  local repo1
  repo1=$(echo "$output" | jq -r '.[0].repo_name')
  if [[ $repo1 != "custom-repo-1" ]]; then
    echo "ERROR: First project repo_name incorrect: $repo1"
    rm -rf "$test_dir"
    return 1
  fi

  # Verify second project (derived repo_name)
  local repo2
  repo2=$(echo "$output" | jq -r '.[1].repo_name')
  if [[ $repo2 != "repo2" ]]; then
    echo "ERROR: Second project repo_name should be derived 'repo2': $repo2"
    rm -rf "$test_dir"
    return 1
  fi

  echo "SUCCESS: Multiple projects extraction works"
  rm -rf "$test_dir"
  return 0
}
