#!/usr/bin/env bash
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

  # Call helper function to perform the actual extraction and metadata generation
  extract_git_path_helper "$abs_path" "$repo_root" "$rel_path"
}