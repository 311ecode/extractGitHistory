#!/usr/bin/env bash

# --- MV Shading ---
register_git_mv_shade() {
  alias mv='git_mv_shaded'
  echo "✅ 'mv' is now shaded (history-aware)."
}

deregister_git_mv_shade() {
  unalias mv 2>/dev/null
  echo "🚫 'mv' shading removed."
}

# --- CP Shading ---
register_git_cp_shade() {
  alias cp='git_cp_shaded'
  echo "✅ 'cp' is now shaded (history-aware)."
}

deregister_git_cp_shade() {
  unalias cp 2>/dev/null
  echo "🚫 'cp' shading removed."
}

# --- Bulk Management ---
register_all_git_shades() {
  register_git_mv_shade
  register_git_cp_shade
}

deregister_all_git_shades() {
  deregister_git_mv_shade
  deregister_git_cp_shade
}
