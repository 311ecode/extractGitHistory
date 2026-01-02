#!/usr/bin/env bash
test_description_extraction_from_real_readme() {
  echo "🧪 Testing description extraction from extracted README"
  local local_repo="/tmp/gh-pusher-test-desc"
  mkdir -p "$local_repo/src"
  cd "$local_repo" && git init -q
  echo "# Functionality Overview" > src/README.md
  git add . && git commit -qm "docs"
  
  local meta_file
  meta_file=$(gitHistoryTools_extractGitPath "$local_repo/src")
  local extracted_path
  extracted_path=$(jq -r '.extracted_repo_path' "$meta_file")
  
  local desc
  desc=$(github_pusher_get_description "$extracted_path" "/orig/path")
  
  rm -rf "$local_repo"

  if [[ "$desc" == "Functionality Overview" ]]; then
    echo "✅ SUCCESS: Extracted description from real file"
    return 0
  else
    echo "❌ ERROR: Extraction failed, got '$desc'"
    return 1
  fi
}