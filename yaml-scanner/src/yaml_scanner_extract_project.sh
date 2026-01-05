#!/usr/bin/env bash
yaml_scanner_extract_project() {
  local yaml_file="$1"
  local github_user="$2"
  local index="$3"
  local debug="${4:-false}"

  # 1. Extract raw path from YAML
  local path=$(yq eval ".projects[$index].path" "$yaml_file")

  if [[ -z $path ]] || [[ $path == "null" ]]; then
    echo "ERROR: Project at index $index has no path" >&2
    return 1
  fi

  # 2. RESOLUTION LOGIC - Ensure we are relative to the YAML file, not the current PWD
  local resolved_path
  if [[ $path == /* ]]; then
    resolved_path="$path"
  else
    # Determine the absolute directory where the YAML file lives
    local yaml_dir=$(cd "$(dirname "$yaml_file")" && pwd)
    local clean_path="${path#./}"
    resolved_path="$yaml_dir/$clean_path"
  fi

  # 3. VERBOSE DEBUG: Trace exactly where we think the code is
  if [[ $debug == "true" ]]; then
    echo "DEBUG: [PATH_RESOLVE] Raw: $path -> Resolved: $resolved_path" >&2
  fi

  if [[ ! -e $resolved_path ]]; then
    echo "ERROR: Path does not exist: $resolved_path" >&2
    return 1
  fi

  # Extract repo_name
  local repo_name=$(yq eval ".projects[$index].repo_name" "$yaml_file")
  [[ $repo_name == "null" || -z $repo_name ]] && repo_name=$(basename "$resolved_path")

  # Helper function for booleans
  get_bool_field() {
    local field="$1"
    local default="$2"
    local val=$(yq eval ".projects[$index].$field" "$yaml_file")
    if [[ $val == "false" || $val == "False" ]]; then
      echo "false"
    elif [[ $val == "true" || $val == "True" ]]; then
      echo "true"
    else echo "$default"; fi
  }

  local is_private=$(get_bool_field "private" "true")
  local force_push=$(get_bool_field "forcePush" "true")
  local pages_enabled=$(get_bool_field "githubPages" "false")

  # Build JSON
  cat <<EOF
{
  "github_user": "$github_user",
  "path": "$resolved_path",
  "repo_name": "$repo_name",
  "private": "$is_private",
  "forcePush": "$force_push",
  "githubPages": "$pages_enabled",
  "githubPagesBranch": "$(yq eval ".projects[$index].githubPagesBranch // \"main\"" "$yaml_file")",
  "githubPagesPath": "$(yq eval ".projects[$index].githubPagesPath // \"/\"" "$yaml_file")"
}
EOF
  return 0
}
