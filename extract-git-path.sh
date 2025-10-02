#!/usr/bin/env bash
# Extract git history for a specific path, flattened to repo root

# Extract git history for a path and output temp directory path
# Usage: extract_git_path <path>
# Returns: 0 on success, 1 on error
# Stdout: Absolute path to extracted git repository
extract_git_path() {
  local target_path="$1"
  local abs_path
  local repo_root
  local rel_path
  local temp_base
  local temp_dir

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

  # Create temp directory structure
  temp_base="${TMPDIR:-/tmp}/extract-git-path"
  mkdir -p "$temp_base"
  temp_dir="$temp_base/extract_$(date +%s)_$$"

  [[ -n "${DEBUG:-}" ]] && echo "DEBUG: Creating temp dir: $temp_dir" >&2

  # Clone repository
  if ! git clone --no-hardlinks "$repo_root" "$temp_dir" >/dev/null 2>&1; then
    echo "ERROR: Failed to clone repository" >&2
    return 1
  fi

  # Extract and flatten history
  cd "$temp_dir" || return 1

  if [[ "$rel_path" != "." ]]; then
    # Use git-filter-repo to extract path and flatten to root
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

  # Output the temp directory path
  echo "$temp_dir"
  return 0
}