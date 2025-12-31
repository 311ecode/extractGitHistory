#!/usr/bin/env bash
G="\033[38;5;46m"
NC="\033[0m" # No Color

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