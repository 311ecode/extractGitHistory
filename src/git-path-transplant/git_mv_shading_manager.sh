#!/usr/bin/env bash

register_git_mv_shade() {
  # Skip if already registered
  if [[ "$(type -t mv)" == "alias" && "$(alias mv)" == *"git_mv_shaded"* ]]; then
    return 0
  fi

  alias mv='git_mv_shaded'
  echo "✅ 'mv' is now shaded (history-aware)."
}

deregister_git_mv_shade() {
  if [[ "$(type -t mv)" == "alias" && "$(alias mv)" == *"git_mv_shaded"* ]]; then
    unalias mv
    echo "🚫 'mv' shading removed."
  fi
}
