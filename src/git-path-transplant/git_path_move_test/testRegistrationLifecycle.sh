#!/usr/bin/env bash

testRegistrationLifecycle() {
  echo "🧪 Testing Granular Registration Lifecycle (State Protected)"
  
  # 1. PROTECT ENVIRONMENT
  # We push the current state of mv and cp aliases if they exist
  push_state alias_mv "$(alias mv 2>/dev/null | sed "s/alias mv='\(.*\)'/\1/")"
  push_state alias_cp "$(alias cp 2>/dev/null | sed "s/alias cp='\(.*\)'/\1/")"

  # Ensure a clean slate for the test
  unalias mv cp 2>/dev/null

  local result=0

  # 2. Test Independent MV
  register_git_mv_shade
  if [[ "$(type -t mv)" != "alias" ]]; then
    echo "❌ ERROR: MV failed to register."
    result=1
  else
    echo "✅ MV registered"
  fi

  if [[ "$(type -t cp)" == "alias" ]]; then
    echo "❌ ERROR: CP accidentally registered during MV registration."
    result=1
  fi

  # 3. Test Independent CP
  register_git_cp_shade
  if [[ "$(type -t cp)" != "alias" ]]; then
    echo "❌ ERROR: CP failed to register."
    result=1
  else
    echo "✅ CP registered"
  fi

  # 4. Test Bulk Deregister
  deregister_all_git_shades
  if [[ "$(type -t mv)" == "alias" || "$(type -t cp)" == "alias" ]]; then
    echo "❌ ERROR: Bulk deregister failed to remove aliases."
    result=1
  else
    echo "✅ Bulk deregistration successful"
  fi

  # 5. Test Bulk Register
  register_all_git_shades
  if [[ "$(type -t mv)" == "alias" && "$(alias mv)" == *"git_mv_shaded"* ]] && \
     [[ "$(type -t cp)" == "alias" && "$(alias cp)" == *"git_cp_shaded"* ]]; then
    echo "✅ Bulk registration successful"
  else
    echo "❌ ERROR: Bulk registration failed."
    result=1
  fi

  # 6. RESTORE ENVIRONMENT
  deregister_all_git_shades
  
  # Retrieve saved values from stack
  local saved_cp=$(pop_state alias_cp)
  local saved_mv=$(pop_state alias_mv)

  # Restore original aliases if they existed
  [[ -n "$saved_mv" ]] && alias mv="$saved_mv"
  [[ -n "$saved_cp" ]] && alias cp="$saved_cp"

  return $result
}
