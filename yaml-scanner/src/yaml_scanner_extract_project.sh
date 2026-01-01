#!/usr/bin/env bash
yaml_scanner_extract_project() {
    local yaml_file="$1"
    local github_user="$2"
    local index="$3"
    local debug="${4:-false}"
    
    # Extract project path
    local path
    path=$(yq eval ".projects[$index].path" "$yaml_file")
    
    if [[ -z "$path" ]] || [[ "$path" == "null" ]]; then
        echo "ERROR: Project at index $index has no path" >&2
        return 1
    fi
    
    # Resolve relative paths
    local resolved_path
    if [[ "$path" = /* ]]; then
        resolved_path="$path"
    else
        # Get absolute directory of the yaml file
        local yaml_dir
        yaml_dir=$(cd "$(dirname "$yaml_file")" && pwd)
        
        # Strip leading ./
        local clean_path="${path#./}"
        resolved_path="$yaml_dir/$clean_path"
    fi

    # Verify path exists before proceeding
    if [[ ! -e "$resolved_path" ]]; then
        echo "ERROR: Path does not exist: $resolved_path" >&2
        return 1
    fi
    
    # Extract repo_name
    local repo_name
    repo_name=$(yq eval ".projects[$index].repo_name" "$yaml_file")
    [[ "$repo_name" == "null" || -z "$repo_name" ]] && repo_name=$(basename "$resolved_path")

    # Build JSON (Minimal/Clean)
    cat <<EOF
{
  "github_user": "$github_user",
  "path": "$resolved_path",
  "repo_name": "$repo_name",
  "private": "$(yq eval ".projects[$index].private // \"true\"" "$yaml_file")",
  "forcePush": "$(yq eval ".projects[$index].forcePush // \"true\"" "$yaml_file")",
  "githubPages": "$(yq eval ".projects[$index].githubPages // \"false\"" "$yaml_file")",
  "githubPagesBranch": "$(yq eval ".projects[$index].githubPagesBranch // \"main\"" "$yaml_file")",
  "githubPagesPath": "$(yq eval ".projects[$index].githubPagesPath // \"/\"" "$yaml_file")"
}
EOF
    return 0
}
