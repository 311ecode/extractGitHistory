#!/usr/bin/env bash

# Helper for debug logging
_log_debug() { [[ -n "${DEBUG:-}" ]] && echo "[DEBUG] $*" >&2; }

# -----------------------------------------------------------------------------
# FUTURE DEVELOPER NOTE: THE CLEANSE HOOK CONTRACT
# -----------------------------------------------------------------------------
# If GIT_PATH_TRANSPLANT_CLEANSE_HOOK is defined as a function name, it will
# be called before any history-scrubbing (git-cleanse) occurs.
#
# Arguments passed to the hook:
#   $1: The original relative path (the source to be scrubbed)
#   $2: The destination relative path (the new home)
#   $3: The path to the metadata JSON file
#
# Return Codes:
#   0: Success - Proceed with git-cleanse
#   Non-zero: Failure - Abort git-cleanse, keep source history intact.
# -----------------------------------------------------------------------------

git_path_transplant() {
  local meta_file="$1"
  local dest_path="$2"
  local use_cleanse="${GIT_PATH_TRANSPLANT_USE_CLEANSE:-0}"
  local cleanse_hook="${GIT_PATH_TRANSPLANT_CLEANSE_HOOK:-}"
  
  _log_debug "--- Starting git_path_transplant ---"

  # Standard Safety Checks
  [[ ! -f "$meta_file" ]] && { echo "❌ Meta file not found"; return 1; }
  [[ -d "$dest_path" ]] && { echo "❌ Destination exists"; return 1; }
  [[ -n "$(git status --porcelain)" ]] && { echo "❌ Working tree dirty"; return 1; }

  # 1. Resolve Metadata
  local extracted_repo=$(jq -r '.extracted_repo_path' "$meta_file")
  local original_rel_path=$(jq -r '.relative_path' "$meta_file")
  local branch_name="history/$dest_path"

  # 2. Fetch & Filter History
  git fetch "$extracted_repo" "HEAD:$branch_name" --force --quiet || return 1
  git filter-repo --refs "$branch_name" --to-subdirectory-filter "$dest_path" --force --quiet || return 1

  # 3. Apply History to Current Branch
  if [[ "${GIT_PATH_TRANSPLANT_USE_REBASE:-}" == "1" ]]; then
    git rebase "$branch_name" --quiet || { git rebase --abort 2>/dev/null; return 1; }
  else
    git merge "$branch_name" --allow-unrelated-histories -m "graft: $dest_path history" --quiet || return 1
  fi
  
  # 4. The Cleanse Decision Engine
  if [[ "$use_cleanse" == "1" ]]; then
    local proceed_with_cleanse=true

    # Check if a validation hook is requested
    if [[ -n "$cleanse_hook" ]]; then
      _log_debug "Invoking safety hook: $cleanse_hook"
      # Note: The function must be exported (export -f) to be visible here
      if ! "$cleanse_hook" "$original_rel_path" "$dest_path" "$meta_file"; then
        echo "⚠️  Safety Hook '$cleanse_hook' returned non-zero. Aborting history scrub."
        proceed_with_cleanse=false
      fi
    fi

    if [[ "$proceed_with_cleanse" == "true" ]]; then
      if git log -1 -- "$original_rel_path" &>/dev/null; then
        echo "🛡️  GIT_PATH_TRANSPLANT: Scrubbing source history for '$original_rel_path'..."
        git-cleanse --yes "$original_rel_path"
      fi
    fi
  fi

  echo "✅ Successfully transplanted history to $dest_path"
}
