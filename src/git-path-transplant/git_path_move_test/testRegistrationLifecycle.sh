#!/usr/bin/env bash

testRegistrationLifecycle() {
  echo "🧪 Testing Registration & Deregistration"
  
  # Save original state
  local original_alias=""
  if [[ "$(type -t mv)" == "alias" ]]; then
    original_alias=$(alias mv)
  fi

  # Ensure clean slate for test
  unalias mv 2>/dev/null

  # 1. Test Registration
  register_git_mv_shade
  if [[ "$(type -t mv)" != "alias" || "$(alias mv)" != *"git_mv_shaded"* ]]; then
    echo "❌ ERROR: Failed to register 'mv' alias."
    return 1
  fi
  echo "✅ Registration successful."

  # 2. Test Deregistration
  deregister_git_mv_shade
  if [[ "$(type -t mv)" == "alias" && "$(alias mv)" == *"git_mv_shaded"* ]]; then
    echo "❌ ERROR: Failed to deregister 'mv' alias."
    return 1
  fi
  echo "✅ Deregistration successful."

  # Restore original state
  if [[ -n "$original_alias" ]]; then
    eval "$original_alias"
    echo "🔄 Original alias state restored."
  fi

  return 0
}
