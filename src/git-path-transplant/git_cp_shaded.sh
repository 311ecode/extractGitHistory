#!/usr/bin/env bash

git_cp_shaded() {
  local has_flags=0
  for arg in "$@"; do
    [[ "$arg" == -* ]] && has_flags=1 && break
  done

  if [[ $# -ne 2 || $has_flags -eq 1 ]]; then
    command cp "$@"
    return $?
  fi

  # Trigger history-aware copy
  if git rev-parse --is-inside-work-tree &>/dev/null; then
    ACT_LIKE_CP=1 git_path_move "$1" "$2"
  else
    command cp "$1" "$2"
  fi
}
