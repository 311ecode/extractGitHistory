#!/usr/bin/env bash
# Extract git history for a specific path, flattened to repo root

# Extract git history for a path and output temp directory path
# Usage: extract_git_path <path>
# Returns: 0 on success, 1 on error
# Stdout: Path to meta.json file
# Stderr: Path to extracted repo (for development convenience)
extract_git_path() {
  local target_path="$1"
  local abs_path
  local repo_root
  local rel_path
  local temp_base
  local temp_dir
  local repo_dir

  # Validate argument
  if [[ $# -ne 1 ]]; then
    echo "ERROR: Usage: extract_git_path <path>" >&2
    return 1
  fi

  # Check dependencies
  if ! command -v git >/dev/null 2>&1; then
    echo "ERROR: git is not installed" >&2
    return 1
  fi

  if ! command -v git-filter-repo >/dev/null 2>&1; then
    echo "ERROR: git-filter-repo is not installed (install: pip install git-filter-repo)" >&2
    return 1
  fi

  # Resolve to absolute path
  if [[ "$target_path" = /* ]]; then
    abs_path="$target_path"
  else
    abs_path="$(cd "$(dirname "$target_path")" 2>/dev/null && pwd)/$(basename "$target_path")"
    if [[ $? -ne 0 ]]; then
      echo "ERROR: Cannot resolve path: $target_path" >&2
      return 1
    fi
  fi

  [[ -n "${DEBUG:-}" ]] && echo "DEBUG: Resolved path: $abs_path" >&2

  # Find git repository root
  local dir="$abs_path"
  repo_root=""
  while [[ "$dir" != "/" ]]; do
    [[ -n "${DEBUG:-}" ]] && echo "DEBUG: Checking for .git in: $dir" >&2
    if [[ -d "$dir/.git" ]]; then
      repo_root="$dir"
      [[ -n "${DEBUG:-}" ]] && echo "DEBUG: Found repo root: $repo_root" >&2
      break
    fi
    dir="$(dirname "$dir")"
  done

  if [[ -z "$repo_root" ]]; then
    echo "ERROR: Path is not inside a git repository: $abs_path" >&2
    return 1
  fi

  # Calculate relative path from repo root
  if [[ "$abs_path" = "$repo_root" ]]; then
    rel_path="."
  else
    rel_path="${abs_path#$repo_root/}"
  fi

  [[ -n "${DEBUG:-}" ]] && echo "DEBUG: Relative path: $rel_path" >&2

  # Verify path exists in git history
  cd "$repo_root" || return 1
  if ! git log --oneline -- "$rel_path" | head -1 | grep -q .; then
    echo "ERROR: Path has no git history (never tracked): $rel_path" >&2
    return 1
  fi

  # Get original commit hashes before extraction
  [[ -n "${DEBUG:-}" ]] && echo "DEBUG: Collecting original commit metadata..." >&2
  
  # Store git log output in variable to avoid process substitution issues
  local git_log_output
  git_log_output=$(git log --reverse --pretty=format:'%H|%aI|%ae|%s' -- "$rel_path")
  
  if [[ -n "${DEBUG:-}" ]]; then
    echo "DEBUG: Raw git log output for path '$rel_path':" >&2
    echo "$git_log_output" >&2
  fi
  
  declare -A original_commits
  while IFS='|' read -r hash date author message; do
    [[ -z "$hash" ]] && continue  # Skip empty lines
    original_commits["$hash"]="$date|$author|$message"
    [[ -n "${DEBUG:-}" ]] && echo "DEBUG: Original commit: $hash | $date | $author | $message" >&2
  done <<< "$git_log_output"

  [[ -n "${DEBUG:-}" ]] && echo "DEBUG: Found ${#original_commits[@]} original commits" >&2

  # Create temp directory structure
  temp_base="${TMPDIR:-/tmp}/extract-git-path"
  mkdir -p "$temp_base"
  temp_dir="$temp_base/extract_$(date +%s)_$$"
  repo_dir="$temp_dir/repo"

  [[ -n "${DEBUG:-}" ]] && echo "DEBUG: Creating temp dir: $temp_dir" >&2

  # Clone repository to repo subdirectory
  if ! git clone --no-hardlinks "$repo_root" "$repo_dir" >/dev/null 2>&1; then
    echo "ERROR: Failed to clone repository" >&2
    return 1
  fi

  # Extract and flatten history
  cd "$repo_dir" || return 1

  if [[ "$rel_path" != "." ]]; then
    # Use git-filter-repo to extract path and flatten to root
    [[ -n "${DEBUG:-}" ]] && echo "DEBUG: Running git-filter-repo..." >&2
    if ! git filter-repo --force --path "$rel_path" --path-rename "$rel_path/:" >/dev/null 2>&1; then
      echo "ERROR: Failed to extract history for path: $rel_path" >&2
      rm -rf "$temp_dir"
      return 1
    fi
  fi

  # Verify extracted repo has commits
  if ! git log --oneline | head -1 | grep -q .; then
    echo "ERROR: No commits found after extraction (this should not happen)" >&2
    rm -rf "$temp_dir"
    return 1
  fi

  # Build commit mapping (old hash -> new hash)
  [[ -n "${DEBUG:-}" ]] && echo "DEBUG: Building commit mappings..." >&2
  
  # Store extracted git log output in variable
  local extracted_log_output
  extracted_log_output=$(git log --reverse --pretty=format:'%H|%aI|%ae|%s')
  
  if [[ -n "${DEBUG:-}" ]]; then
    echo "DEBUG: Extracted git log output:" >&2
    echo "$extracted_log_output" >&2
  fi
  
  declare -A commit_mappings
  
  while IFS='|' read -r new_hash date author message; do
    [[ -z "$new_hash" ]] && continue  # Skip empty lines
    [[ -n "${DEBUG:-}" ]] && echo "DEBUG: New commit: $new_hash | $date | $author | $message" >&2
    
    # Find matching original commit by date, author, and message
    local found=false
    for old_hash in "${!original_commits[@]}"; do
      IFS='|' read -r old_date old_author old_message <<< "${original_commits[$old_hash]}"
      
      if [[ "$date" == "$old_date" && "$author" == "$old_author" && "$message" == "$old_message" ]]; then
        commit_mappings["$old_hash"]="$new_hash"
        [[ -n "${DEBUG:-}" ]] && echo "DEBUG: Matched: $old_hash -> $new_hash" >&2
        unset "original_commits[$old_hash]"  # Remove to avoid duplicate matches
        found=true
        break
      fi
    done
    
    if [[ "$found" == false ]] && [[ -n "${DEBUG:-}" ]]; then
      echo "DEBUG: WARNING - No match found for new commit $new_hash" >&2
    fi
  done <<< "$extracted_log_output"

  [[ -n "${DEBUG:-}" ]] && echo "DEBUG: Mapped ${#commit_mappings[@]} commits" >&2
  
  # Show unmapped original commits if any
  if [[ -n "${DEBUG:-}" ]] && [[ ${#original_commits[@]} -gt 0 ]]; then
    echo "DEBUG: WARNING - ${#original_commits[@]} original commits not mapped:" >&2
    for old_hash in "${!original_commits[@]}"; do
      echo "DEBUG:   Unmapped: $old_hash -> ${original_commits[$old_hash]}" >&2
    done
  fi

  # Generate extract-git-path-meta.json
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

  # Write commit mappings
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

  }
}
EOF

  [[ -n "${DEBUG:-}" ]] && echo "DEBUG: Generated metadata at: $meta_file" >&2

  # Output repo path to stderr for development convenience
  echo "$repo_dir" >&2

  # Output extract-git-path-meta.json path to stdout
  echo "$meta_file"
  return 0
}