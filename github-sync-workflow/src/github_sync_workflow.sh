#!/usr/bin/env bash
github_sync_workflow() {
    command -v markdown-show-help-registration &>/dev/null && eval "$(markdown-show-help-registration)"
    local yaml_file="${1:-.github-sync.yaml}"
    local dry_run="${2:-false}"
    local debug="${DEBUG:-false}"
    
    # Normalize debug value
    if [[ "$debug" == "1" ]]; then
        debug="true"
    fi
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: github_sync_workflow - Starting GitHub sync workflow" >&2
        echo "DEBUG: github_sync_workflow - YAML file: $yaml_file" >&2
        echo "DEBUG: github_sync_workflow - Dry run: $dry_run" >&2
    fi
    
    # Step 1: Scan YAML configuration
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: github_sync_workflow - Step 1 - Scanning YAML configuration..." >&2
    fi
    
    # TEMPORARY CHANGE: Removed output redirection (>/dev/null 2>&1)
    # to allow error messages from yaml_scanner to pass through.
    if ! yaml_scanner "$yaml_file"; then
        echo "ERROR: YAML scanning failed" >&2
        return 1
    fi
    
    # Get JSON output path from YAML
    local json_output
    json_output=$(yaml_scanner_get_json_output_path "$yaml_file")
    
    if [[ -z "$json_output" ]] || [[ "$json_output" == "null" ]]; then
        echo "ERROR: json_output not defined in YAML config" >&2
        echo "ERROR: Please add 'json_output: /path/to/output.json' to your YAML" >&2
        return 1
    fi
    
    if [[ ! -f "$json_output" ]]; then
        echo "ERROR: JSON output file not found: $json_output" >&2
        return 1
    fi
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: github_sync_workflow - Projects JSON: $json_output" >&2
    fi
    
    # Process projects using helper function
    github_sync_workflow_process_projects "$json_output" "$dry_run" "$debug"
}
