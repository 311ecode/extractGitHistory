#!/usr/bin/env bash
# YAML scanner for extracting GitHub repository metadata

yaml_scanner_parse_config() {
    local yaml_file="$1"
    local debug="${2:-false}"
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: Parsing YAML config: $yaml_file" >&2
    fi
    
    if [[ ! -f "$yaml_file" ]]; then
        echo "ERROR: YAML file not found: $yaml_file" >&2
        return 1
    fi
    
    # Check if yq is available
    if ! command -v yq >/dev/null 2>&1; then
        echo "ERROR: yq is not installed (install: pip install yq)" >&2
        return 1
    fi
    
    return 0
}

yaml_scanner_get_project_count() {
    local yaml_file="$1"
    
    # Get the length of the projects array
    yq -r '.projects | length' "$yaml_file" 2>/dev/null
}

yaml_scanner_extract_project() {
    local yaml_file="$1"
    local index="$2"
    local debug="${3:-false}"
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: Extracting project at index $index" >&2
    fi
    
    # Extract github_user
    local github_user
    github_user=$(yq -r ".projects[$index].github_user // empty" "$yaml_file" 2>/dev/null)
    
    if [[ -z "$github_user" ]] || [[ "$github_user" == "null" ]]; then
        if [[ "$debug" == "true" ]]; then
            echo "DEBUG: No github_user at index $index" >&2
        fi
        return 1
    fi
    
    # Extract path
    local path
    path=$(yq -r ".projects[$index].path // empty" "$yaml_file" 2>/dev/null)
    
    if [[ -z "$path" ]] || [[ "$path" == "null" ]]; then
        if [[ "$debug" == "true" ]]; then
            echo "DEBUG: No path at index $index" >&2
        fi
        return 1
    fi
    
    # Extract repo_name (optional)
    local repo_name
    repo_name=$(yq -r ".projects[$index].repo_name // empty" "$yaml_file" 2>/dev/null)
    
    # If no explicit repo_name, derive from path
    if [[ -z "$repo_name" ]] || [[ "$repo_name" == "null" ]]; then
        repo_name=$(basename "$path")
        if [[ "$debug" == "true" ]]; then
            echo "DEBUG: Derived repo_name from path: $repo_name" >&2
        fi
    fi
    
    # Output JSON for this project
    cat <<EOF
{
  "github_user": "$github_user",
  "path": "$path",
  "repo_name": "$repo_name"
}
EOF
    
    return 0
}

yaml_scanner() {
    local yaml_file="${1:-.github-sync.yaml}"
    local debug="${DEBUG:-false}"
    
    # If no argument provided, look for default file in current directory
    if [[ ! -f "$yaml_file" ]]; then
        echo "ERROR: YAML file not found: $yaml_file" >&2
        return 1
    fi
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: Scanning YAML file: $yaml_file" >&2
        echo "DEBUG: YAML contents:" >&2
        cat "$yaml_file" >&2
    fi
    
    # Parse and validate YAML
    if ! yaml_scanner_parse_config "$yaml_file" "$debug"; then
        return 1
    fi
    
    # Get number of projects
    local project_count
    project_count=$(yaml_scanner_get_project_count "$yaml_file")
    
    if [[ -z "$project_count" ]] || [[ "$project_count" == "null" ]] || [[ "$project_count" -eq 0 ]]; then
        echo "ERROR: No projects found in YAML" >&2
        return 1
    fi
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: Found $project_count projects" >&2
    fi
    
    # Start JSON array
    echo "["
    
    # Extract each project
    local first=true
    for ((i=0; i<project_count; i++)); do
        local project_json
        project_json=$(yaml_scanner_extract_project "$yaml_file" "$i" "$debug")
        
        if [[ $? -eq 0 ]]; then
            if [[ "$first" == "true" ]]; then
                first=false
            else
                echo ","
            fi
            echo "$project_json" | sed 's/^/  /'  # Indent for array
        fi
    done
    
    # End JSON array
    echo ""
    echo "]"
    
    return 0
}