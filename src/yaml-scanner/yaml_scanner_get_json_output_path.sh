#!/usr/bin/env bash
yaml_scanner_get_json_output_path() {
    local yaml_file="$1"
    
    yq -r '.json_output // empty' "$yaml_file"
}