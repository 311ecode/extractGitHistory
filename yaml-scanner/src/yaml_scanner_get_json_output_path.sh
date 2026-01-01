#!/usr/bin/env bash
yaml_scanner_get_json_output_path() {
    local yaml_file="$1"
    echo "TRACE [yaml_scanner_get_json_output_path]: Fetching JSON output path from YAML file: $yaml_file" >&2
    yq eval '.json_output' "$yaml_file"
    echo "TRACE [yaml_scanner_get_json_output_path]: JSON output path fetched successfully" >&2
}
