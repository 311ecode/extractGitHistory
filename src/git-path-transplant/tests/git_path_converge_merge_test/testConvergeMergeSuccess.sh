testConvergeMergeSuccess() {
  echo "🧪 Testing Convergent Merge (Multiple sources with shared history)"
  
  push_state DEBUG "1"
  push_state PWD
  # Ensure cleanse is off so BFG doesn't delete results
  push_state GIT_PATH_TRANSPLANT_USE_CLEANSE "0" 

  local tmp_dir=$(mktemp -d)
  local result=0

  (
    cd "$tmp_dir" || exit 1

    # 1. Setup Shared Base
    mkdir base_repo && cd base_repo
    git init -q
    git config user.email "shared@test.com" && git config user.name "BaseAuthor"
    echo "shared content" > core.js
    git add . && git commit -m "feat: shared base logic" -q
    local shared_commit_msg="feat: shared base logic"
    cd "$tmp_dir"

    # 2. Create Fork A
    git clone base_repo repoA -q
    cd repoA
    echo "feature A" > featureA.js
    git add . && git commit -m "feat: add feature A" -q
    cd "$tmp_dir"

    # 3. Create Fork B
    git clone base_repo repoB -q
    cd repoB
    echo "feature B" > featureB.js
    git add . && git commit -m "feat: add feature B" -q
    cd "$tmp_dir"

    # 4. Create Monorepo
    mkdir monorepo && cd monorepo
    git init -q
    git config user.email "tester@test.com" && git config user.name "Tester"
    echo "# Monorepo" > README.md
    git add . && git commit -m "init: monorepo" -q

    # 5. Execute (Sourcing removed, uses memory)
    echo "🚀 Merging repoA and repoB into 'unified_app'..."
    git_path_converge_merge "unified_app" "$tmp_dir/repoA" "$tmp_dir/repoB"
    
    if [[ $? -ne 0 ]]; then
      echo "❌ ERROR: git_path_converge_merge failed"
      exit 1
    fi

    # 6. Verifications
    echo "🔍 Verifying results..."
    [[ -f "unified_app/featureA.js" ]] || { echo "❌ Missing featureA.js"; exit 1; }
    [[ -f "unified_app/featureB.js" ]] || { echo "❌ Missing featureB.js"; exit 1; }
    [[ -f "unified_app/core.js" ]] || { echo "❌ Missing core.js"; exit 1; }

    local shared_count=$(git log --oneline -- "unified_app" | grep -c "$shared_commit_msg")
    if [[ $shared_count -eq 0 ]]; then
      echo "❌ ERROR: Shared history was lost!"
      exit 1
    fi

    echo "✅ SUCCESS: Converged merge verified."
    exit 0
  )
  result=$?
  rm -rf "$tmp_dir"

  pop_state GIT_PATH_TRANSPLANT_USE_CLEANSE
  pop_state PWD
  pop_state DEBUG
  return $result
}