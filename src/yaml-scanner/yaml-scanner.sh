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

yaml_scanner_get_github_user() {
    local yaml_file="$1"
    
    yq -r '.github_user // empty' "$yaml_file" 2>/dev/null
}

yaml_scanner_get_json_output_path() {
    local yaml_file="$1"
    
    yq -r '.json_output // empty' "$yaml_file" 2>/dev/null
}

yaml_scanner_get_project_count() {
    local yaml_file="$1"
    
    # Get the length of the projects array
    yq -r '.projects | length' "$yaml_file" 2>/dev/null
}

yaml_scanner_extract_project() {
    local yaml_file="$1"
    local github_user="$2"
    local index="$3"
    local debug="${4:-false}"
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: Extracting project at index $index" >&2
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
    
    # Extract private setting (optional, defaults to true)
    local private
    private=$(yq -r ".projects[$index].private // \"true\"" "$yaml_file" 2>/dev/null)
    
    # Convert to boolean
    if [[ "$private" == "false" ]]; then
        private="false"
    else
        private="true"
    fi
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: Repository will be private: $private" >&2
    fi
    
    # Output JSON for this project
    cat <<EOF
{
  "github_user": "$github_user",
  "path": "$path",
  "repo_name": "$repo_name",
  "private": $private
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
    
    # Get github_user (required at top level)
    local github_user
    github_user=$(yaml_scanner_get_github_user "$yaml_file")
    
    if [[ -z "$github_user" ]] || [[ "$github_user" == "null" ]]; then
        echo "ERROR: github_user not found in YAML" >&2
        return 1
    fi
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: GitHub user: $github_user" >&2
    fi
    
    # Get json_output path (optional)
    local json_output
    json_output=$(yaml_scanner_get_json_output_path "$yaml_file")
    
    if [[ -n "$json_output" ]] && [[ "$json_output" != "null" ]]; then
        if [[ "$debug" == "true" ]]; then
            echo "DEBUG: JSON output will be saved to: $json_output" >&2
        fi
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
    
    # Build JSON output
    local json_content=""
    
    # Start JSON array
    json_content+="["$'\n'
    
    # Extract each project
    local first=true
    for ((i=0; i<project_count; i++)); do
        local project_json
        project_json=$(yaml_scanner_extract_project "$yaml_file" "$github_user" "$i" "$debug")
        
        if [[ $? -eq 0 ]]; then
            if [[ "$first" == "true" ]]; then
                first=false
            else
                json_content+=","$'\n'
            fi
            json_content+="$(echo "$project_json" | sed 's/^/  /')"  # Indent for array
        fi
    done
    
    # End JSON array
    json_content+=$'\n'"]"
    
    # Output or save JSON
    if [[ -n "$json_output" ]] && [[ "$json_output" != "null" ]]; then
        # Create directory if it doesn't exist
        local output_dir
        output_dir=$(dirname "$json_output")
        if [[ ! -d "$output_dir" ]]; then
            mkdir -p "$output_dir"
        fi
        
        # Write to file
        echo "$json_content" > "$json_output"
        
        if [[ $? -eq 0 ]]; then
            echo "JSON output saved to: $json_output" >&2
        else
            echo "ERROR: Failed to write JSON output to: $json_output" >&2
            return 1
        fi
    else
        # Output to stdout
        echo "$json_content"
    fi
    
    return 0
}