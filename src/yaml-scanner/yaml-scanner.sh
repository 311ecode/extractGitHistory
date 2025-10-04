#!/usr/bin/env bash
# YAML scanner for extracting GitHub repository metadata

# ... (keep all functions the same until yaml_scanner) ...

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
    
    # Extract each project and track failures
    local first=true
    local failed_count=0
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
        else
            ((failed_count++))
        fi
    done
    
    # End JSON array
    json_content+=$'\n'"]"
    
    # Check if all projects failed
    if [[ $failed_count -gt 0 ]]; then
        echo "ERROR: Failed to process $failed_count project(s)" >&2
        return 1
    fi
    
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