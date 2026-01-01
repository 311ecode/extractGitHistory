#!/usr/bin/env bash
yaml_scanner_parse_config() {
    local yaml_file="$1"
    local debug="${2:-false}"
    
    if [[ "$debug" == "true" ]]; then
        echo "DEBUG: Validating YAML config: $yaml_file" >&2
    fi
    
    # Check if yq is installed
    if ! command -v yq >/dev/null 2>&1; then
        echo "ERROR: yq is not installed" >&2
        return 1
    fi
    
    # Validate YAML syntax (yq v4 syntax)
    if ! yq eval '.' "$yaml_file" >/dev/null 2>&1; then
        echo "ERROR: Invalid YAML syntax in $yaml_file" >&2
        return 1
    fi
    
    return 0
}
