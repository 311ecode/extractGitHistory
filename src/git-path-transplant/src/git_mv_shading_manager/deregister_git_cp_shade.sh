#!/usr/bin/env bash
G="\033[38;5;46m"
NC="\033[0m" # No Color

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