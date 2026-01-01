#!/usr/bin/env bash
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