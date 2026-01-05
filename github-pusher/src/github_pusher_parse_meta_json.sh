#!/usr/bin/env bash
github_pusher_parse_meta_json() {
  local meta_file="$1"
  local debug="${2:-false}"

  if [[ $debug == "true" ]]; then
    echo "DEBUG: Parsing meta JSON: $meta_file" >&2
  fi

  if [[ ! -f $meta_file ]]; then
    echo "ERROR: Meta file not found: $meta_file" >&2
    return 1
  fi

  # Verify it's valid JSON
  if ! jq empty "$meta_file" 2>/dev/null; then
    echo "ERROR: Invalid JSON in meta file" >&2
    return 1
  fi

  return 0
}
