#!/usr/bin/env bash

git_path_merge_many() {
  local operations=("$@")
  
  if [[ ${#operations[@]} -eq 0 ]]; then
    echo "ERROR: Usage: git_path_merge_many <source1:dest1> [<source2:dest2> ...]" >&2
    echo "Example: git_path_merge_many 'repoA/utils:vendor/A/utils' 'repoB/tools:vendor/B/tools'" >&2
    return 1
  fi

  [[ -n "${DEBUG:-}" ]] && echo "DEBUG: Starting multi-path merge operation with ${#operations[@]} operations" >&2

  # ═══════════════════════════════════════════════════════════
  # 1. Validation Phase
  # ═══════════════════════════════════════════════════════════
  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo "ERROR: Not in a git repository" >&2
    return 1
  }

  # Check for dirty working tree
  if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    echo "ERROR: Working tree has uncommitted changes. Commit or stash them first." >&2
    return 1
  fi

  # Parse and validate all operations first
  local -a sources=()
  local -a destinations=()
  local -a meta_files=()
  
  echo "🔍 Validating ${#operations[@]} operations..."
  for op in "${operations[@]}"; do
    if [[ ! "$op" =~ ^(.+):(.+)$ ]]; then
      echo "ERROR: Invalid operation format: '$op'" >&2
      echo "       Expected format: 'source/path:destination/path'" >&2
      return 1
    fi
    
    local src="${BASH_REMATCH[1]}"
    local dst="${BASH_REMATCH[2]}"
    
    # Check if source exists
    if [[ ! -e "$src" ]]; then
      echo "ERROR: Source path does not exist: '$src'" >&2
      return 1
    fi
    
    # Check if destination already exists
    if [[ -e "$repo_root/$dst" ]]; then
      echo "ERROR: Destination already exists: '$dst'" >&2
      return 1
    fi
    
    sources+=("$src")
    destinations+=("$dst")
    
    [[ -n "${DEBUG:-}" ]] && echo "DEBUG: Validated: $src → $dst" >&2
  done
  
  echo "✅ All operations validated"

  # ═══════════════════════════════════════════════════════════
  # 2. Extraction Phase
  # ═══════════════════════════════════════════════════════════
  echo ""
  echo "📦 Extracting ${#sources[@]} source histories..."
  
  for i in "${!sources[@]}"; do
    local src="${sources[$i]}"
    echo "  [$((i+1))/${#sources[@]}] Extracting: $src"
    
    local meta
    meta=$(extract_git_path "$src") || {
      echo "ERROR: Failed to extract '$src'" >&2
      # Cleanup any already extracted repos
      for existing_meta in "${meta_files[@]}"; do
        [[ -f "$existing_meta" ]] && rm -rf "$(dirname "$existing_meta")"
      done
      return 1
    }
    
    meta_files+=("$meta")
    [[ -n "${DEBUG:-}" ]] && echo "DEBUG: Extracted metadata: $meta" >&2
  done
  
  echo "✅ All extractions complete"

  # ═══════════════════════════════════════════════════════════
  # 3. Create Savepoint
  # ═══════════════════════════════════════════════════════════
  local savepoint_branch="savepoint/merge-many-$(date +%Y%m%d-%H%M%S)"
  git branch "$savepoint_branch" HEAD
  [[ -n "${DEBUG:-}" ]] && echo "DEBUG: Created savepoint: $savepoint_branch" >&2

  # ═══════════════════════════════════════════════════════════
  # 4. Transplant Phase (with rollback on failure)
  # ═══════════════════════════════════════════════════════════
  echo ""
  echo "🌱 Transplanting ${#meta_files[@]} histories..."
  
  local transplant_failed=0
  local -a history_branches=()
  
  for i in "${!meta_files[@]}"; do
    local meta="${meta_files[$i]}"
    local dst="${destinations[$i]}"
    local src="${sources[$i]}"
    
    echo "  [$((i+1))/${#meta_files[@]}] Transplanting: $src → $dst"
    
    # Capture the history branch name before transplant
    local branch_name="${GIT_PATH_TRANSPLANT_HISTORY_BRANCH:-}"
    
    if ! git_path_transplant "$meta" "$dst"; then
      echo "❌ ERROR: Failed to transplant '$src' to '$dst'" >&2
      transplant_failed=1
      break
    fi
    
    # Record history branch if it was created
    # The branch name should still be in the environment or we can detect it
    local created_branch=$(git branch --list "history/transplant-*" | tail -1 | sed 's/^[* ]*//')
    if [[ -n "$created_branch" ]]; then
      history_branches+=("$created_branch")
      [[ -n "${DEBUG:-}" ]] && echo "DEBUG: Recorded history branch: $created_branch" >&2
    fi
  done

  # ═══════════════════════════════════════════════════════════
  # 5. Rollback or Finalize
  # ═══════════════════════════════════════════════════════════
  if [[ $transplant_failed -eq 1 ]]; then
    echo ""
    echo "🔄 Rolling back all changes..."
    git reset --hard "$savepoint_branch"
    git branch -D "$savepoint_branch" 2>/dev/null
    
    # Cleanup history branches
    for branch in "${history_branches[@]}"; do
      git branch -D "$branch" 2>/dev/null || true
    done
    
    # Cleanup extracted repos
    for meta in "${meta_files[@]}"; do
      [[ -f "$meta" ]] && rm -rf "$(dirname "$meta")"
    done
    
    echo "❌ Multi-path merge FAILED and rolled back"
    return 1
  fi

  # ═══════════════════════════════════════════════════════════
  # 6. Create Final Annotation Commit
  # ═══════════════════════════════════════════════════════════
  echo ""
  echo "💾 Creating annotation commit..."
  
  # Build commit message documenting the multi-path operation
  local commit_msg="docs: multi-path history transplant completed

Successfully transplanted ${#operations[@]} paths with full history:
"
  for i in "${!sources[@]}"; do
    commit_msg+="
  - ${sources[$i]} → ${destinations[$i]}"
  done
  
  commit_msg+="

Each path retains its complete commit history via git-filter-repo extraction.

History branches preserved:
"
  for branch in "${history_branches[@]}"; do
    commit_msg+="
  - $branch"
  done

  # Create an empty commit as a marker (doesn't change tree)
  git commit --allow-empty -m "$commit_msg" || {
    echo "WARNING: Failed to create annotation commit (non-fatal)" >&2
  }

  # ═══════════════════════════════════════════════════════════
  # 7. Cleanup (but preserve history branches)
  # ═══════════════════════════════════════════════════════════
  git branch -D "$savepoint_branch" 2>/dev/null
  
  # Cleanup extracted repos
  for meta in "${meta_files[@]}"; do
    [[ -f "$meta" ]] && rm -rf "$(dirname "$meta")"
  done

  echo ""
  echo "✅ SUCCESS: Multi-path merge completed!"
  echo "   Transplanted: ${#operations[@]} paths"
  echo "   History branches: ${#history_branches[@]}"
  echo "   Current commit: $(git rev-parse --short HEAD)"
  
  return 0
}
