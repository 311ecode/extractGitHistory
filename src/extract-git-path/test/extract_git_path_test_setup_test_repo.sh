#!/usr/bin/env bash
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