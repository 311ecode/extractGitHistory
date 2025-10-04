#!/usr/bin/env bash
yaml_scanner_get_github_user() {
    local yaml_file="$1"
    
    yq -r '.github_user // empty' "$yaml_file"
}