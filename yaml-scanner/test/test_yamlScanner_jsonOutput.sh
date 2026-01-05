#!/usr/bin/env bash
test_yamlScanner_jsonOutput() {
  echo "Testing JSON output to file"

  local test_dir=$(mktemp -d)
  local yaml_file="$test_dir/.github-sync.yaml"
  local json_output="$test_dir/output/projects.json"

  # Create the actual directories so the scanner's existence check passes
  mkdir -p "$test_dir/repo1"
  mkdir -p "$test_dir/repo2"

  cat >"$yaml_file" <<EOF
github_user: testuser
json_output: $json_output

projects:
  - path: $test_dir/repo1
    repo_name: test-repo-1
  - path: $test_dir/repo2
EOF

  # Run scanner - capture stderr for checking success message
  local stderr_output
  stderr_output=$(yaml_scanner "$yaml_file" 2>&1 >/dev/null)
  local exit_code=$?

  if [[ $exit_code -ne 0 ]]; then
    echo "ERROR: yaml_scanner failed"
    echo "$stderr_output"
    rm -rf "$test_dir"
    return 1
  fi

  # Verify file was created
  if [[ ! -f $json_output ]]; then
    echo "ERROR: JSON output file not created at $json_output"
    rm -rf "$test_dir"
    return 1
  fi

  # Verify JSON content using jq
  local repo1
  repo1=$(jq -r '.[0].repo_name' "$json_output")
  if [[ $repo1 != "test-repo-1" ]]; then
    echo "ERROR: Incorrect repo_name in saved JSON: $repo1"
    rm -rf "$test_dir"
    return 1
  fi

  local repo2
  repo2=$(jq -r '.[1].repo_name' "$json_output")
  if [[ $repo2 != "repo2" ]]; then
    echo "ERROR: Derived repo_name incorrect: $repo2"
    rm -rf "$test_dir"
    return 1
  fi

  echo "SUCCESS: JSON output to file works"
  rm -rf "$test_dir"
  return 0
}
