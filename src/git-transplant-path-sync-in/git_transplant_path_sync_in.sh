#!/usr/bin/env bash

git_transplant_path_sync_in() {
    command -v markdown-show-help-registration &>/dev/null && eval "$(markdown-show-help-registration --minimum-parameters 2)"

  local meta_json="$1"
  local poly_url="$2"
  local debug="${DEBUG:-}"
  local run_id=$(head /dev/urandom | tr -dc a-z0-9 | head -c 6)

  # 1. Capture State
  local rel_path=$(jq -r '.relative_path' "$meta_json")
  local current_branch=$(git rev-parse --abbrev-ref HEAD)
  
  # 2. Fetch Polyrepo
  local temp_remote="sync_remote_${run_id}"
  git remote add "$temp_remote" "$poly_url"
  git fetch "$temp_remote" --quiet

  # FIX: Use --verify and -q to ensure a single-line clean hash
  local poly_head
  poly_head=$(git rev-parse -q --verify "$temp_remote/main^{commit}" 2>/dev/null || \
              git rev-parse -q --verify "$temp_remote/master^{commit}" 2>/dev/null)
  
  if [[ -z "$poly_head" ]]; then
    echo "❌ ERROR: Could not resolve Polyrepo HEAD" >&2
    git remote remove "$temp_remote"
    return 1
  fi

  # 3. Path Transformation
  local scratch_branch="scratch_sync_${run_id}"
  # Ensure we stop if the checkout fails
  if ! git checkout -b "$scratch_branch" "$poly_head" --quiet; then
      echo "❌ ERROR: Failed to create scratch branch from $poly_head" >&2
      return 1
  fi
  
  [[ -n "$debug" ]] && echo "🧪 DEBUG: Prefixing history with $rel_path" >&2
  git filter-repo --to-subdirectory-filter "$rel_path" --force --quiet

  local prepared_head=$(git rev-parse HEAD)

  # 4. Adoption (Mirroring)
  git checkout "$current_branch" --quiet
  git reset --hard "$prepared_head" --quiet

  # 5. Metadata Update
  local current_head=$(git rev-parse HEAD)
  local updated_meta=$(jq --arg poly "$poly_head" \
                    --arg mono "$current_head" \
                    --arg url "$poly_url" \
                    --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
                    '.git_transplant_path_sync_in = {
                        "last_run_timestamp": $ts,
                        "remote_url": $url,
                        "last_synced_poly_hash": $poly,
                        "last_synced_mono_hash": $mono
                      }' "$meta_json")
  
  echo "$updated_meta" > "$meta_json"
  
  # 6. Cleanup
  git remote remove "$temp_remote"
  git branch -D "$scratch_branch" --quiet 2>/dev/null || true
  
  return 0
}
