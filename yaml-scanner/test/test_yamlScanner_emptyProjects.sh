#!/usr/bin/env bash
test_yamlScanner_emptyProjects() {
  echo "Testing error handling for empty projects list"

  local test_dir=$(mktemp -d)
  local yaml_file="$test_dir/.github-sync.yaml"

  cat >"$yaml_file" <<'EOF'
github_user: testuser

projects: []
EOF

  cd "$test_dir"
  local output
  output=$(yaml_scanner "$yaml_file" 2>&1)
  local exit_code=$?

  cd - >/dev/null
  rm -rf "$test_dir"

  if [[ $exit_code -eq 0 ]]; then
    echo "ERROR: Should fail with empty projects list"
    return 1
  fi

  if ! echo "$output" | grep -q "No projects found"; then
    echo "ERROR: Missing expected error message"
    echo "$output"
    return 1
  fi

  echo "SUCCESS: Empty projects error handling works"
  return 0
}
