#!/usr/bin/env bash
test_name_generation_from_real_meta() {
  echo "🧪 Testing name generation using gitHistoryTools_extractGitPath metadata"
  local local_repo="/tmp/gh-pusher-test-name"
  mkdir -p "$local_repo/my-cool-feature"
  cd "$local_repo" && git init -q && touch "my-cool-feature/init" && git add . && git commit -qm "init"
  
  local meta_file
  meta_file=$(gitHistoryTools_extractGitPath "$local_repo/my-cool-feature")
  
  local generated_name
  generated_name=$(github_pusher_generate_repo_name "$meta_file")
  
  rm -rf "$local_repo"

  if [[ "$generated_name" == "my-cool-feature" ]]; then
    echo "✅ SUCCESS: Correctly derived name from real metadata"
    return 0
  else
    echo "❌ ERROR: Expected 'my-cool-feature', got '$generated_name'"
    return 1
  fi
}