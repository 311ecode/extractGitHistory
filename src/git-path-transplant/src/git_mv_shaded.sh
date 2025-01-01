#!/usr/bin/env bash

git_mv_shaded() {
  # 1. Bypass if flags are detected or argument count is not exactly 2
  local has_flags=0
  for arg in "$@"; do
    [[ "$arg" == -* ]] && has_flags=1 && break
  done

  if [[ $# -ne 2 || $has_flags -eq 1 ]]; then
    if git rev-parse --is-inside-work-tree &>/dev/null; then
      command git mv "$@"
    else
      command mv "$@"
    fi
    return $?
  fi

  local src="$1"
  local dst="$2"

  # 2. Logic Gate: If in Git, use history-preserving move
  if git rev-parse --is-inside-work-tree &>/dev/null; then
    # We call the existing git_path_move from your library
    git_path_move "$src" "$dst"
  else
    # Fallback for non-git environments
    command mv "$src" "$dst"
  fi
}
