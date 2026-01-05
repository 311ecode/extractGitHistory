#!/usr/bin/env bash
yaml_scanner_get_project_count() {
  local yaml_file="$1"

  yq eval '.projects | length' "$yaml_file"
}
