#!/usr/bin/env bash

# --- Color Definitions ---
G="\033[38;5;46m"
NC="\033[0m" # No Color

_is_mv_shaded() { alias mv 2>/dev/null | grep -q 'git_mv_shaded'; }
_is_cp_shaded() { alias cp 2>/dev/null | grep -q 'git_cp_shaded'; }

# --- Move (MV) Functions ---
register_git_mv_shade() {
  if _is_mv_shaded; then
    echo "ℹ️ 'mv' is already shaded."
  else
    alias mv='git_mv_shaded'
    echo -e "✅ 'mv' is now shaded. Use ${G}deregister_git_mv_shade${NC} to undo."
    if _is_cp_shaded; then
      echo -e "💡 Both active. Run ${G}deregister_all_git_shades${NC} to turn off both."
    fi
  fi
}

deregister_git_mv_shade() {
  if _is_mv_shaded; then
    unalias mv
    echo -e "🚫 'mv' shading removed. Use ${G}register_git_mv_shade${NC} to enable."
    if ! _is_cp_shaded; then
      echo -e "💡 Both inactive. Run ${G}register_all_git_shades${NC} to turn on both."
    fi
  else
    echo "ℹ️ 'mv' is not currently shaded."
  fi
}

# --- Copy (CP) Functions ---
register_git_cp_shade() {
  if _is_cp_shaded; then
    echo "ℹ️ 'cp' is already shaded."
  else
    alias cp='git_cp_shaded'
    echo -e "✅ 'cp' is now shaded. Use ${G}deregister_git_cp_shade${NC} to undo."
    if _is_mv_shaded; then
      echo -e "💡 Both active. Run ${G}deregister_all_git_shades${NC} to turn off both."
    fi
  fi
}

deregister_git_cp_shade() {
  if _is_cp_shaded; then
    unalias cp
    echo -e "🚫 'cp' shading removed. Use ${G}register_git_cp_shade${NC} to enable."
    if ! _is_mv_shaded; then
      echo -e "💡 Both inactive. Run ${G}register_all_git_shades${NC} to turn on both."
    fi
  else
    echo "ℹ️ 'cp' is not currently shaded."
  fi
}

# --- Bulk Toggle Functions ---
register_all_git_shades() {
  register_git_mv_shade
  register_git_cp_shade
}

deregister_all_git_shades() {
  deregister_git_mv_shade
  deregister_git_cp_shade
}