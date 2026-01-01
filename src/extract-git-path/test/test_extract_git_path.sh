#!/usr/bin/env bash
test_extract_git_path() {
  export LC_NUMERIC=C

  # Helper to setup a dummy git repo for testing
  extract_git_path_test_setup_test_repo() {
    local repo_dir="$1"
    mkdir -p "$repo_dir"
    cd "$repo_dir" || return 1
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    
    # Create some history
    mkdir src
    echo "content1" > src/file1.txt
    git add src/file1.txt
    git commit -qm "Initial commit"
    
    echo "content2" >> src/file1.txt
    git add src/file1.txt
    git commit -qm "Update file1"
    
    echo "other" > other.txt
    git add other.txt
    git commit -qm "Unrelated file"
  }

  test_argument_validation() {
    echo "🧪 Testing argument validation"
    local err_msg
    err_msg=$(extract_git_path 2>&1)
    if [[ "$err_msg" == *"Usage: extract_git_path <path>"* ]]; then
      echo "✅ SUCCESS: Caught missing arguments"
      return 0
    else
      echo "❌ ERROR: Failed to validate arguments"
      return 1
    fi
  }

  test_outside_git_repo() {
    echo "🧪 Testing execution outside of a git repository"
    local tmp_dir
    tmp_dir=$(mktemp -d)
    
    # Run in a non-git directory
    local err_msg
    err_msg=$(cd "$tmp_dir" && extract_git_path "$tmp_dir" 2>&1)
    
    rm -rf "$tmp_dir"
    
    if [[ "$err_msg" == *"not inside a git repository"* ]]; then
      echo "✅ SUCCESS: Correctly identified non-repo path"
      return 0
    else
      echo "❌ ERROR: Failed to detect non-git directory"
      return 1
    fi
  }

  test_successful_extraction() {
    echo "🧪 Testing successful directory extraction"
    local main_repo
    main_repo=$(mktemp -d)
    extract_git_path_test_setup_test_repo "$main_repo"

    # Run extraction on the 'src' directory
    local meta_file
    meta_file=$(extract_git_path "$main_repo/src")
    
    if [[ ! -f "$meta_file" ]]; then
      echo "❌ ERROR: Metadata file not created"
      return 1
    fi

    # Parse metadata for extracted path (using grep/sed for portability in bash)
    local extracted_repo
    extracted_repo=$(grep "extracted_repo_path" "$meta_file" | cut -d'"' -f4)

    if [[ -d "$extracted_repo" && -f "$extracted_repo/file1.txt" ]]; then
      # Check that unrelated files are gone
      if [[ ! -f "$extracted_repo/other.txt" ]]; then
        echo "✅ SUCCESS: Directory extracted and flattened correctly"
        return 0
      fi
    fi

    echo "❌ ERROR: Extraction content mismatch"
    return 1
  }

  test_commit_mapping_logic() {
    echo "🧪 Testing commit mapping metadata"
    local main_repo
    main_repo=$(mktemp -d)
    extract_git_path_test_setup_test_repo "$main_repo"

    local meta_file
    meta_file=$(extract_git_path "$main_repo/src")
    
    # Verify commit_mappings block exists and is not empty
    if grep -q "commit_mappings" "$meta_file" && grep -q "test@example.com" -v "$meta_file"; then
       # Verify we have at least 2 mapped commits (initial and update)
       local mapping_count
       mapping_count=$(grep -c "\": \"" "$meta_file")
       if [[ $mapping_count -ge 2 ]]; then
         echo "✅ SUCCESS: Commits correctly mapped in metadata"
         return 0
       fi
    fi

    echo "❌ ERROR: Commit mapping failed"
    return 1
  }

  # Test function registry 📋
  local test_functions=(
    "test_argument_validation"
    "test_outside_git_repo"
    "test_successful_extraction"
    "test_commit_mapping_logic"
  )

  local ignored_tests=()

  bashTestRunner test_functions ignored_tests
  return $?
}