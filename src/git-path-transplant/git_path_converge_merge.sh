#!/usr/bin/env bash

git_path_converge_merge() {
  local destination="$1"
  shift
  local sources=("$@")
  
  if [[ ${#sources[@]} -lt 2 ]]; then
    echo "ERROR: Usage: git_path_converge_merge <destination> <source1> [<source2> ...]" >&2
    echo "Example: git_path_converge_merge 'unified/feature' 'repoA/feature' 'repoB/feature' 'repoC/feature'" >&2
    return 1
  fi

  [[ -n "${DEBUG:-}" ]] && echo "DEBUG: Converge merge: ${#sources[@]} sources → $destination" >&2

  # ═══════════════════════════════════════════════════════════
  # 1. Validation Phase
  # ═══════════════════════════════════════════════════════════
  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo "ERROR: Not in a git repository" >&2
    return 1
  }

  if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    echo "ERROR: Working tree has uncommitted changes. Commit or stash them first." >&2
    return 1
  fi

  if [[ -e "$repo_root/$destination" ]]; then
    echo "ERROR: Destination already exists: '$destination'" >&2
    return 1
  fi

  echo "🔍 Validating ${#sources[@]} source paths..."
  for src in "${sources[@]}"; do
    if [[ ! -e "$src" ]]; then
      echo "ERROR: Source path does not exist: '$src'" >&2
      return 1
    fi
    [[ -n "${DEBUG:-}" ]] && echo "DEBUG: Validated source: $src" >&2
  done
  echo "✅ All sources validated"

  # ═══════════════════════════════════════════════════════════
  # 2. Extract All Sources
  # ═══════════════════════════════════════════════════════════
  echo ""
  echo "📦 Extracting ${#sources[@]} source histories..."
  
  local -a meta_files=()
  local -a extracted_repos=()
  
  for i in "${!sources[@]}"; do
    local src="${sources[$i]}"
    echo "  [$((i+1))/${#sources[@]}] Extracting: $src"
    
    local meta
    meta=$(extract_git_path "$src") || {
      echo "ERROR: Failed to extract '$src'" >&2
      # Cleanup
      for existing_meta in "${meta_files[@]}"; do
        [[ -f "$existing_meta" ]] && rm -rf "$(dirname "$existing_meta")"
      done
      return 1
    }
    
    meta_files+=("$meta")
    extracted_repos+=("$(jq -r '.extracted_repo_path' "$meta")")
    [[ -n "${DEBUG:-}" ]] && echo "DEBUG: Extracted to: ${extracted_repos[$i]}" >&2
  done
  
  echo "✅ All extractions complete"

  # ═══════════════════════════════════════════════════════════
  # 3. Build Commit Metadata Maps
  # ═══════════════════════════════════════════════════════════
  echo ""
  echo "🔍 Analyzing commit relationships..."
  
  # For each extracted repo, build a map of commits by their "signature"
  # Signature = message + author + date (content-independent identity)
  local -A commit_signatures  # signature -> "repo_index:commit_hash"
  local -A commit_by_repo     # "repo_index:signature" -> commit_hash
  
  for i in "${!extracted_repos[@]}"; do
    local repo="${extracted_repos[$i]}"
    
    [[ -n "${DEBUG:-}" ]] && echo "DEBUG: Analyzing repo $i: $repo" >&2
    
    # Get all commits with their metadata
    while IFS='|' read -r hash message author date; do
      # Create signature (normalize whitespace)
      local sig="${message}|${author}|${date}"
      sig=$(echo "$sig" | tr -s ' ' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      
      commit_by_repo["${i}:${sig}"]="$hash"
      
      # Track if we've seen this signature before (indicates shared history)
      if [[ -n "${commit_signatures[$sig]:-}" ]]; then
        commit_signatures["$sig"]="${commit_signatures[$sig]} ${i}:${hash}"
      else
        commit_signatures["$sig"]="${i}:${hash}"
      fi
      
      [[ -n "${DEBUG:-}" ]] && echo "DEBUG:   [$i] $hash: $message" >&2
    done < <(cd "$repo" && git log --all --format='%H|%s|%an <%ae>|%ai')
  done

  # ═══════════════════════════════════════════════════════════
  # 4. Identify Common Base and Divergence Points
  # ═══════════════════════════════════════════════════════════
  echo ""
  echo "🔍 Identifying shared history..."
  
  local common_count=0
  local -a common_signatures=()
  
  for sig in "${!commit_signatures[@]}"; do
    local repos="${commit_signatures[$sig]}"
    local repo_count=$(echo "$repos" | wc -w)
    
    if [[ $repo_count -gt 1 ]]; then
      common_count=$((common_count + 1))
      common_signatures+=("$sig")
      [[ -n "${DEBUG:-}" ]] && echo "DEBUG: Common commit found in $repo_count repos: ${sig%%|*}" >&2
    fi
  done
  
  echo "✅ Found $common_count shared commits across sources"
  
  if [[ $common_count -eq 0 ]]; then
    echo "⚠️  WARNING: No shared history detected. Sources appear unrelated."
    echo "   Proceeding with unrelated history merge..."
  fi

  # ═══════════════════════════════════════════════════════════
  # 5. Create Temporary Merge Workspace
  # ═══════════════════════════════════════════════════════════
  echo ""
  echo "🔧 Creating merge workspace..."
  
  local merge_workspace=$(mktemp -d)
  cd "$merge_workspace" && git init -q
  git config user.email "converge@git-path-transplant"
  git config user.name "Convergent Merge Bot"
  
  [[ -n "${DEBUG:-}" ]] && echo "DEBUG: Merge workspace: $merge_workspace" >&2

  # ═══════════════════════════════════════════════════════════
  # 6. Import First Source as Base
  # ═══════════════════════════════════════════════════════════
  echo ""
  echo "🌱 Importing base history from source 0..."
  
  git fetch "${extracted_repos[0]}" HEAD:source-0 --quiet
  git checkout source-0 --quiet
  
  local merge_failed=0

  # ═══════════════════════════════════════════════════════════
  # 7. Merge Each Additional Source
  # ═══════════════════════════════════════════════════════════
  for i in $(seq 1 $((${#extracted_repos[@]} - 1))); do
    echo ""
    echo "🔀 Merging source $i..."
    
    git fetch "${extracted_repos[$i]}" HEAD:source-$i --quiet
    
    # Attempt merge with strategy for unrelated histories
    if git merge source-$i --allow-unrelated-histories -m "merge: converge source $i (${sources[$i]})" --quiet 2>/dev/null; then
      echo "✅ Source $i merged cleanly"
    else
      # Check if there are conflicts
      if git diff --check 2>/dev/null; then
        # No conflicts, just needs commit
        git commit --no-edit --quiet 2>/dev/null || true
        echo "✅ Source $i merged (auto-resolved)"
      else
        echo "❌ CONFLICT: Source $i has merge conflicts"
        echo ""
        echo "Conflicted files:"
        git diff --name-only --diff-filter=U
        echo ""
        echo "Please resolve conflicts manually in: $merge_workspace"
        echo "Then run: git add . && git commit"
        echo ""
        echo "Workspace preserved at: $merge_workspace"
        merge_failed=1
        break
      fi
    fi
  done

  if [[ $merge_failed -eq 1 ]]; then
    echo ""
    echo "❌ Converge merge FAILED due to conflicts"
    echo "   Workspace preserved for manual resolution: $merge_workspace"
    return 1
  fi

  # ═══════════════════════════════════════════════════════════
  # 8. Transplant Merged Result to Destination
  # ═══════════════════════════════════════════════════════════
  echo ""
  echo "🚀 Transplanting merged result to $destination..."
  
  cd "$repo_root"
  
  # Create metadata for the merged workspace
  local merged_meta=$(mktemp)
  cat > "$merged_meta" <<EOF
{
  "extracted_repo_path": "$merge_workspace",
  "original_repo_root": "$merge_workspace",
  "relative_path": ".",
  "extraction_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "commit_count": $(cd "$merge_workspace" && git rev-list --count HEAD)
}
EOF

  if ! git_path_transplant "$merged_meta" "$destination"; then
    echo "❌ ERROR: Failed to transplant merged result"
    rm -f "$merged_meta"
    return 1
  fi
  
  rm -f "$merged_meta"

  # ═══════════════════════════════════════════════════════════
  # 9. Cleanup
  # ═══════════════════════════════════════════════════════════
  echo ""
  echo "🧹 Cleaning up..."
  
  for meta in "${meta_files[@]}"; do
    [[ -f "$meta" ]] && rm -rf "$(dirname "$meta")"
  done
  
  rm -rf "$merge_workspace"

  # ═══════════════════════════════════════════════════════════
  # 10. Success
  # ═══════════════════════════════════════════════════════════
  echo ""
  echo "✅ SUCCESS: Convergent merge completed!"
  echo "   Sources merged: ${#sources[@]}"
  echo "   Shared commits: $common_count"
  echo "   Destination: $destination"
  echo "   Current commit: $(git rev-parse --short HEAD)"
  
  return 0
}
