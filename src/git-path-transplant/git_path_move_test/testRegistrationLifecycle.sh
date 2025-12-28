#!/usr/bin/env bash

testRegistrationLifecycle() {
  echo "🧪 Testing Granular Registration Lifecycle"
  
  # Save original states
  local orig_mv="" && [[ "$(type -t mv)" == "alias" ]] && orig_mv=$(alias mv)
  local orig_cp="" && [[ "$(type -t cp)" == "alias" ]] && orig_cp=$(alias cp)

  # Clean slate
  unalias mv cp 2>/dev/null

  # 1. Test Independent MV
  register_git_mv_shade
  [[ "$(type -t mv)" != "alias" ]] || echo "✅ MV registered"
  [[ "$(type -t cp)" == "alias" ]] && echo "❌ CP accidentally registered" && return 1

  # 2. Test Independent CP
  register_git_cp_shade
  [[ "$(type -t cp)" != "alias" ]] || echo "✅ CP registered"

  # 3. Test Bulk Deregister
  deregister_all_git_shades
  [[ "$(type -t mv)" == "alias" || "$(type -t cp)" == "alias" ]] && echo "❌ Bulk deregister failed" && return 1
  echo "✅ Bulk deregistration successful"

  # 4. Test Bulk Register
  register_all_git_shades
  [[ "$(type -t mv)" == "alias" && "$(alias mv)" == *"git_mv_shaded"* ]] || return 1
  [[ "$(type -t cp)" == "alias" && "$(alias cp)" == *"git_cp_shaded"* ]] || return 1
  echo "✅ Bulk registration successful"

  # Cleanup and Restore
  deregister_all_git_shades
  [[ -n "$orig_mv" ]] && eval "$orig_mv"
  [[ -n "$orig_cp" ]] && eval "$orig_cp"

  return 0
}
