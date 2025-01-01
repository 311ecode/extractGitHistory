#!/usr/bin/env bash

testUnicodePathMove() {
  echo "🧪 Testing Unicode and Space Path Move (📁 My Folder)"
  
  # 1. PROTECT ENVIRONMENT
  push_state DEBUG "1"
  push_state PWD
  push_state LC_ALL "en_US.UTF-8" # Ensure shell handles unicode correctly
  export LC_ALL

  local tmp_dir=$(mktemp -d)
  local result=0

  (
    # Setup Repo
    mkdir -p "$tmp_dir/repo" && cd "$tmp_dir/repo" && git init -q
    git config user.email "unicode@test.com"
    git config user.name "EmojiBot"

    # Create a source with spaces and emoji
    local src_name="📁 My Source"
    local dst_name="🚀 My Destination"
    
    mkdir -p "$src_name"
    echo "unicode data" > "$src_name/file with spaces.txt"
    git add . && git commit -m "feat: unicode path" -q

    # --- EXECUTE MOVE ---
    # This tests the quoting logic in git_path_move and extract_git_path
    git_path_move "$src_name" "$dst_name"

    # --- VERIFICATION ---
    if [[ ! -f "$dst_name/file with spaces.txt" ]]; then
      echo "❌ ERROR: Destination file missing or path incorrectly resolved."
      ls -R
      exit 1
    fi

    if [[ -d "$src_name" ]]; then
      echo "❌ ERROR: Source directory '$src_name' was not removed."
      exit 1
    fi

    # Check history preservation on the space-heavy path
    local history_count=$(git log --oneline -- "$dst_name" | wc -l)
    if [[ $history_count -eq 0 ]]; then
      echo "❌ ERROR: History lost during unicode move."
      exit 1
    fi

    echo "✅ SUCCESS: Unicode and space-filled paths moved successfully."
    exit 0
  )
  result=$?

  # 2. RESTORE ENVIRONMENT
  pop_state LC_ALL
  pop_state PWD
  pop_state DEBUG

  return $result
}
