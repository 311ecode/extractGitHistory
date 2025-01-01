#!/usr/bin/env bash

git_cp_shaded() {
  local has_unsupported_flags=0
  local is_recursive=0
  local paths=()

  # 1. Parse arguments: Filter for -r/-R, detect other flags
  for arg in "$@"; do
    if [[ "$arg" == "-r" || "$arg" == "-R" ]]; then
      is_recursive=1
    elif [[ "$arg" == -* ]]; then
      has_unsupported_flags=1
    else
      paths+=("$arg")
    fi
  done

  # 2. Logic Gate: If 2 paths and no "dirty" flags, use history engine
  if [[ ${#paths[@]} -eq 2 && $has_unsupported_flags -eq 0 ]]; then
    if git rev-parse --is-inside-work-tree &>/dev/null; then
      # Even if -r wasn't passed, we treat directory copies as history-forks
      GIT_PATH_TRANSPLANT_ACT_LIKE_CP=1 git_path_move "${paths[0]}" "${paths[1]}"
      return $?
    fi
  fi

  # 3. Fallback
  command cp "$@"
}
