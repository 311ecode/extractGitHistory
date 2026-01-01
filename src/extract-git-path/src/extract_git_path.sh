#!/usr/bin/env bash
extract_git_path() {
  command -v markdown-show-help-registration &>/dev/null && eval "$(markdown-show-help-registration --minimum-parameters 1)"
  local target_path="$1"
  local abs_path
  local repo_root
  local rel_path

  # Validate argument
  if [[ $# -ne 1 ]]; then
    echo "ERROR: Usage: extract_git_path <path>" >&2
    return 1
  fi

  # Resolve to absolute path 
  # This block handles: /abs/path, ./rel/path, and ../../parent/path
  if [[ -d "$target_path" ]]; then
    abs_path=$(cd "$target_path" && pwd)
  elif [[ -f "$target_path" ]]; then
    abs_path=$(cd "$(dirname "$target_path")" && pwd)/$(basename "$target_path")
  else
    # Fallback for paths that might contain symlinks or complex navigation
    abs_path=$(readlink -f "$target_path" 2>/dev/null || realpath "$target_path" 2>/dev/null)
  fi

  if [[ -z "$abs_path" || ! -e "$abs_path" ]]; then
    echo "ERROR: Cannot resolve path: $target_path" >&2
    return 1
  fi

  # Find git repository root by climbing up from the absolute path
  local dir="$abs_path"
  repo_root=""
  while [[ "$dir" != "/" ]]; do
    if [[ -d "$dir/.git" ]]; then
      repo_root="$dir"
      break
    fi
    dir="$(dirname "$dir")"
  done

  if [[ -z "$repo_root" ]]; then
    echo "ERROR: Path is not inside a git repository: $abs_path" >&2
    return 1
  fi

  # Calculate relative path from repo root
  rel_path="${abs_path#$repo_root/}"
  [[ "$abs_path" == "$repo_root" ]] && rel_path="."

  # Delegate to helper
  extract_git_path_helper "$abs_path" "$repo_root" "$rel_path"
}
