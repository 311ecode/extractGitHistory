#!/usr/bin/env bash
git_mv_shaded() {
  # ───────────────────────────────────────────────────────────────
  # Safety-first version – only intercept the most obvious case
  # Everything else → plain old mv
  # ───────────────────────────────────────────────────────────────

  # 1. Quick bypass for anything that looks non-trivial
  if [[ $# -ne 2 ]]; then
    command mv "$@"
    return $?
  fi

  # 2. Check for any flag-like argument
  for arg in "$@"; do
    if [[ $arg == -* ]]; then
      command mv "$@"
      return $?
    fi
  done

  local src="$1"
  local dst="$2"

  # 3. Only now: are we in a git repo?
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    command mv "$src" "$dst"
    return $?
  fi

  # 4. Final safety: do both paths look reasonable? (no leading dash, not empty)
  if [[ -z "$src" || -z "$dst" || "$src" == -* || "$dst" == -* ]]; then
    command mv "$src" "$dst"
    return $?
  fi

  # ── Only reach here for the clean, simple, safe case ──
  echo "→ Using history-preserving move: $src → $dst" >&2
  git_path_move "$src" "$dst"
}