#!/usr/bin/env bash

testHistoryParityMagic() {
  echo "🧪 Testing History Parity Magic ($A \to B \to C$ vs $A' \to B' \to C'$)"
  local tmp_dir=$(mktemp -d)
  cd "$tmp_dir" && git init -q
  git config user.email "magic@test.com"
  git config user.name "Wizard"

  # 1. Create original history A -> B -> C
  mkdir -p "origin_dir"
  echo "A" > origin_dir/file.txt && git add . && \
    GIT_AUTHOR_DATE="2025-01-01T12:00:00" git commit -m "Commit A" -q
  echo "B" >> origin_dir/file.txt && git add . && \
    GIT_AUTHOR_DATE="2025-01-02T12:00:00" git commit -m "Commit B" -q
  echo "C" >> origin_dir/file.txt && git add . && \
    GIT_AUTHOR_DATE="2025-01-03T12:00:00" git commit -m "Commit C" -q

  # 2. Perform the Magic Copy
  git_cp_shaded "origin_dir" "magic_copy"

  # 3. Verify Metadata Parity
  echo "🔍 Comparing Commit Sequences..."
  
  # Get logs for both paths (Message|Author|Date)
  local log_orig=$(git log --format="%s|%an|%ad" -- "origin_dir")
  local log_copy=$(git log --format="%s|%an|%ad" -- "magic_copy")

  if [[ "$log_orig" != "$log_copy" ]]; then
    echo "❌ ERROR: Metadata mismatch!"
    echo "Original Chain:" && echo "$log_orig"
    echo "Magic Chain:" && echo "$log_copy"
    return 1
  fi

  # 4. Verify Content Parity
  if [[ "$(cat magic_copy/file.txt)" != "A
B
C" ]]; then
    echo "❌ ERROR: File content did not survive the magic transplant."
    return 1
  fi

  echo "✅ SUCCESS: $A' \to B' \to C'$ is a perfect metadata mirror of $A \to B \to C$."
  return 0
}
