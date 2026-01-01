#!/usr/bin/env bash
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