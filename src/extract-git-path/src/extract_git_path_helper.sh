#!/usr/bin/env bash
extract_git_path_helper() {
  local abs_path="$1"
  local repo_root="$2"
  local rel_path="$3"

  local temp_base="${TMPDIR:-/tmp}/extract-git-path"
  mkdir -p "$temp_base" || {
    echo "ERROR: Cannot create temp base directory $temp_base" >&2
    return 1
  }

  # Create a truly unique temporary directory
  local temp_dir
  temp_dir=$(mktemp -d "$temp_base/extract_XXXXXXXXXX") || {
    echo "ERROR: Failed to create unique temporary directory" >&2
    return 1
  }

  # Auto-cleanup on exit (very useful)
  trap '[[ -d "$temp_dir" && -n "$temp_dir" ]] && rm -rf "$temp_dir" 2>/dev/null' EXIT

  local repo_dir="$temp_dir/repo"

  [[ -n "${DEBUG:-}" ]] && echo "DEBUG: Creating temp dir: $temp_dir" >&2

  # Collect original commit metadata
  [[ -n "${DEBUG:-}" ]] && echo "DEBUG: Collecting original commit metadata..." >&2

  local git_log_output
  git_log_output=$(git -C "$repo_root" log --reverse --pretty=format:'%H|%aI|%ae|%s' -- "$rel_path" 2>/dev/null)

  if [[ -z "$git_log_output" ]]; then
    echo "ERROR: No commit history found for path: $rel_path" >&2
    return 1
  fi

  if [[ -n "${DEBUG:-}" ]]; then
    echo "DEBUG: Raw git log output for path '$rel_path':" >&2
    echo "$git_log_output" >&2
  fi

  declare -A original_commits
  while IFS='|' read -r hash date author message; do
    [[ -z "$hash" ]] && continue
    original_commits["$hash"]="$date|$author|$message"
    [[ -n "${DEBUG:-}" ]] && echo "DEBUG: Original commit: $hash | $date | $author | $message" >&2
  done <<< "$git_log_output"

  [[ -n "${DEBUG:-}" ]] && echo "DEBUG: Found ${#original_commits[@]} original commits" >&2

  # Clone the repository
  if ! git clone --no-hardlinks "$repo_root" "$repo_dir" >/dev/null 2>&1; then
    echo "ERROR: Failed to clone repository from $repo_root to $repo_dir" >&2
    return 1
  fi

  cd "$repo_dir" || { echo "ERROR: Cannot cd into $repo_dir" >&2; return 1; }

  # Extract and flatten to root
  if [[ "$rel_path" != "." ]]; then
    [[ -n "${DEBUG:-}" ]] && echo "DEBUG: Running git-filter-repo for path: $rel_path" >&2

    if [[ -f "$repo_root/$rel_path" ]]; then
      # === FILE: Flatten to root using basename ===
      local basename="${rel_path##*/}"
      if ! git filter-repo --force \
           --path "$rel_path" \
           --path-rename "$rel_path:$basename" \
           >/dev/null 2>&1; then
        echo "ERROR: git filter-repo failed for file: $rel_path" >&2
        return 1
      fi
    else
      # === DIRECTORY: Move contents to root ===
      if ! git filter-repo --force \
           --path "$rel_path/" \
           --path-rename "$rel_path/:" \
           >/dev/null 2>&1; then
        echo "ERROR: git filter-repo failed for directory: $rel_path" >&2
        return 1
      fi
    fi
  fi

  # Verify extraction produced commits
  if ! git log --oneline -n 1 >/dev/null 2>&1; then
    echo "ERROR: No commits found after extraction" >&2
    return 1
  fi

  # Build commit mapping
  [[ -n "${DEBUG:-}" ]] && echo "DEBUG: Building commit mappings..." >&2

  local extracted_log_output
  extracted_log_output=$(git log --reverse --pretty=format:'%H|%aI|%ae|%s')

  if [[ -n "${DEBUG:-}" ]]; then
    echo "DEBUG: Extracted git log output:" >&2
    echo "$extracted_log_output" >&2
  fi

  declare -A commit_mappings

  while IFS='|' read -r new_hash date author message; do
    [[ -z "$new_hash" ]] && continue

    [[ -n "${DEBUG:-}" ]] && echo "DEBUG: New commit: $new_hash | $date | $author | $message" >&2

    local found=false
    for old_hash in "${!original_commits[@]}"; do
      IFS='|' read -r old_date old_author old_message <<< "${original_commits[$old_hash]}"

      if [[ "$date" == "$old_date" && "$author" == "$old_author" && "$message" == "$old_message" ]]; then
        commit_mappings["$old_hash"]="$new_hash"
        [[ -n "${DEBUG:-}" ]] && echo "DEBUG: Matched: $old_hash -> $new_hash" >&2
        unset "original_commits[$old_hash]"
        found=true
        break
      fi
    done

    if [[ "$found" == false ]] && [[ -n "${DEBUG:-}" ]]; then
      echo "DEBUG: WARNING - No matching original commit found for: $new_hash" >&2
    fi
  done <<< "$extracted_log_output"

  [[ -n "${DEBUG:-}" ]] && echo "DEBUG: Mapped ${#commit_mappings[@]} commits" >&2

  # Generate metadata JSON
  local meta_file="$temp_dir/extract-git-path-meta.json"
  local extraction_timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  cat > "$meta_file" <<EOF
{
  "original_path": "$abs_path",
  "original_repo_root": "$repo_root",
  "relative_path": "$rel_path",
  "extracted_repo_path": "$repo_dir",
  "extraction_timestamp": "$extraction_timestamp",
  "commit_mappings": {
EOF

  local first=true
  for old_hash in "${!commit_mappings[@]}"; do
    if [[ "$first" == true ]]; then
      first=false
    else
      echo "," >> "$meta_file"
    fi
    echo -n "    \"$old_hash\": \"${commit_mappings[$old_hash]}\"" >> "$meta_file"
  done

  cat >> "$meta_file" <<EOF
  },
  "sync_status": {
    "synced": false,
    "github_url": null,
    "github_owner": null,
    "github_repo": null,
    "synced_at": null,
    "synced_by": null
  }
}
EOF

  [[ -n "${DEBUG:-}" ]] && echo "DEBUG: Generated metadata at: $meta_file" >&2

  # Output results
  echo "$repo_dir" >&2
  echo "$meta_file"

  return 0
}
